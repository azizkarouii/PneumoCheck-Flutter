from fastapi import FastAPI, UploadFile, File, Depends, HTTPException, status, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel, EmailStr
from jose import JWTError, jwt
from datetime import datetime, timedelta
import psycopg2
import psycopg2.extras
import tensorflow as tf
import numpy as np
from PIL import Image
import io
import base64
import cv2
import bcrypt


# ── CONFIG ────────────────────────────────────────────────────────────────────

SECRET_KEY    = "change_this_secret_key_in_production"
ALGORITHM     = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24h

DB_CONFIG = {
    "host":     "localhost",
    "port":     5432,
    "database": "pneumocheck",
    "user":     "postgres",
    "password": "system"
}

# ── INIT ──────────────────────────────────────────────────────────────────────

app = FastAPI(title="PneumoCheck API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

oauth2_scheme  = OAuth2PasswordBearer(tokenUrl="/auth/login")

# Charger le modèle au démarrage
print("Chargement du modèle...")
model = tf.keras.models.load_model("model/pneumocheck_model.keras")
print("Modèle chargé ✅")

# ── DATABASE ──────────────────────────────────────────────────────────────────

def get_db():
    conn = psycopg2.connect(**DB_CONFIG)
    try:
        yield conn
    finally:
        conn.close()

# ── MODÈLES PYDANTIC ──────────────────────────────────────────────────────────

class UserRegister(BaseModel):
    name:     str
    email:    EmailStr
    phone:    str
    speciality: str
    avatar_b64: str | None = None
    password: str

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

class Token(BaseModel):
    access_token: str
    token_type:   str

# ── AUTH UTILS ────────────────────────────────────────────────────────────────

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode('utf-8'), hashed.encode('utf-8'))

def create_token(data: dict) -> str:
    to_encode = data.copy()
    expire    = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def create_password_reset_token(user_id: int) -> str:
    payload = {
        "sub": str(user_id),
        "scope": "password_reset",
        "exp": datetime.utcnow() + timedelta(minutes=15)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def verify_password_reset_token(token: str) -> int:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("scope") != "password_reset":
            raise HTTPException(status_code=400, detail="Token de réinitialisation invalide")
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=400, detail="Token de réinitialisation invalide")
        return int(user_id)
    except JWTError:
        raise HTTPException(status_code=400, detail="Token de réinitialisation invalide ou expiré")

def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Token invalide")
        return int(user_id)
    except JWTError:
        raise HTTPException(status_code=401, detail="Token invalide")

# ── GRAD-CAM ──────────────────────────────────────────────────────────────────

def generate_gradcam(img_array: np.ndarray, image_bytes: bytes) -> tuple[str, str]:
    # Grad-CAM standard + post-traitements pour une carte plus localisée.
    # Cherche la dernière Conv2D dans le modèle ou ses sous-modèles (backbone).
    last_conv_layer = None
    parent_model = None
    for layer in reversed(model.layers):
        if isinstance(layer, tf.keras.layers.Conv2D):
            last_conv_layer = layer
            parent_model = model
            break
    if last_conv_layer is None:
        for layer in reversed(model.layers):
            if hasattr(layer, "layers"):
                for sub in reversed(layer.layers):
                    if isinstance(sub, tf.keras.layers.Conv2D):
                        last_conv_layer = sub
                        parent_model = layer
                        break
            if last_conv_layer:
                break

    if last_conv_layer is None:
        raise RuntimeError("Aucune couche Conv2D trouvée pour Grad-CAM")

    # Utiliser l'entrée du parent/backbone pour garder la connectivité
    backbone = parent_model if parent_model is not None else model

    # trouver l'index de la dernière conv dans le backbone
    last_conv_index = None
    for idx in range(len(backbone.layers) - 1, -1, -1):
        if isinstance(backbone.layers[idx], tf.keras.layers.Conv2D):
            last_conv_layer = backbone.layers[idx]
            last_conv_index = idx
            break
    if last_conv_index is None:
        raise RuntimeError("Aucune couche Conv2D trouvée dans le backbone pour Grad-CAM")

    conv_model = tf.keras.models.Model(inputs=backbone.input, outputs=last_conv_layer.output)

    with tf.GradientTape() as tape:
        conv_outputs = conv_model(img_array)
        tape.watch(conv_outputs)

        # rejouer la queue du backbone + reste du modèle pour obtenir prédictions connectées
        x = conv_outputs
        tail_layers = list(backbone.layers[last_conv_index + 1 :])
        try:
            backbone_index = list(model.layers).index(backbone)
            tail_layers += list(model.layers[backbone_index + 1 :])
        except ValueError:
            if backbone is not model:
                tail_layers += list(model.layers[1:])

        for layer in tail_layers:
            if isinstance(layer, (tf.keras.layers.BatchNormalization, tf.keras.layers.Dropout)):
                x = layer(x, training=False)
            else:
                x = layer(x)

        predictions = x
        # Utiliser le logit (pré-activation) pour obtenir des gradients mieux localisés
        prob = tf.clip_by_value(predictions[:, 0], 1e-7, 1.0 - 1e-7)
        loss = tf.math.log1p(prob)

    grads = tape.gradient(loss, conv_outputs)
    if grads is None:
        raise RuntimeError("Impossible de calculer les gradients pour Grad-CAM (grads est None)")

    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2)).numpy()
    conv_outputs = conv_outputs[0].numpy()  # (h,w,channels)

    # pondérer canaux par gradients
    for i in range(pooled_grads.shape[-1]):
        conv_outputs[:, :, i] *= pooled_grads[i]

    heatmap = np.sum(conv_outputs, axis=-1)
    heatmap = np.maximum(heatmap, 0)
    if np.max(heatmap) > 0:
        heatmap = heatmap / (np.max(heatmap) + 1e-8)

    # resize -> lissage
    heatmap_resized = cv2.resize(heatmap, (224, 224), interpolation=cv2.INTER_LINEAR)
    try:
        heatmap_resized = cv2.GaussianBlur(heatmap_resized, (9, 9), 0)
    except Exception:
        pass

    # Seuil percentile pour ne garder que les activations fortes (rend la carte plus localisée)
    pct = 60
    cutoff = np.percentile(heatmap_resized, pct)
    heatmap_thresh = np.where(heatmap_resized >= cutoff, heatmap_resized, 0.0)

    # Morphologie : dilatation + closing pour obtenir une zone cohérente
    try:
        kernel = np.ones((7, 7), np.uint8)
        heatmap_uint8 = np.uint8(255 * np.clip(heatmap_thresh, 0, 1))
        heatmap_morph = cv2.dilate(heatmap_uint8, kernel, iterations=2)
        heatmap_morph = cv2.morphologyEx(heatmap_morph, cv2.MORPH_CLOSE, kernel, iterations=2)
        heatmap_resized = heatmap_morph.astype(np.float32) / 255.0
    except Exception:
        heatmap_resized = heatmap_thresh

    # léger renforcement de contraste
    heatmap_resized = np.power(np.clip(heatmap_resized, 0, 1), 1.1)

    # Heuristique améliorée : segmenter les champs pulmonaires puis appliquer le masque
    try:
        gray = cv2.cvtColor(original, cv2.COLOR_RGB2GRAY)
        # corps par Otsu (évite le fond noir)
        _, body_mask = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        body_mask = cv2.medianBlur(body_mask, 5)
        k = np.ones((15, 15), np.uint8)
        body_mask = cv2.morphologyEx(body_mask, cv2.MORPH_CLOSE, k, iterations=2)

        # détecter régions foncées (poumons) par seuillage adaptatif inversé
        adapt = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY_INV, 51, 10)
        lungs_candidate = cv2.bitwise_and(adapt, body_mask)
        lungs_candidate = cv2.morphologyEx(lungs_candidate, cv2.MORPH_OPEN, np.ones((5,5), np.uint8), iterations=1)

        # garder les deux plus grandes composantes (gauche/droite)
        contours, _ = cv2.findContours(lungs_candidate, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if contours:
            contours = sorted(contours, key=cv2.contourArea, reverse=True)
            mask_lungs = np.zeros_like(lungs_candidate)
            for c in contours[:2]:
                if cv2.contourArea(c) > 500:  # ignore tiny
                    cv2.drawContours(mask_lungs, [c], -1, 255, thickness=-1)
            # dilater légèrement pour couvrir bords
            mask_lungs = cv2.dilate(mask_lungs, np.ones((11,11), np.uint8), iterations=2)
        else:
            mask_lungs = body_mask

        # réduire marges verticales trop hautes/basses
        h, w = mask_lungs.shape
        top = int(h * 0.05)
        bottom = int(h * 0.95)
        mask_lungs[:top, :] = 0
        mask_lungs[bottom:, :] = 0

        mask_float = (mask_lungs.astype(np.float32) / 255.0)
        heatmap_resized = heatmap_resized * mask_float
        # renormaliser si nécessaire
        if np.max(heatmap_resized) > 0:
            heatmap_resized = heatmap_resized / (np.max(heatmap_resized) + 1e-8)
    except Exception:
        pass

    # Colorize & overlay
    heatmap_uint8 = np.uint8(255 * heatmap_resized)
    heatmap_colored = cv2.applyColorMap(heatmap_uint8, cv2.COLORMAP_JET)

    original = Image.open(io.BytesIO(image_bytes)).convert('RGB').resize((224, 224))
    original = np.array(original, dtype=np.uint8)
    original_bgr = cv2.cvtColor(original, cv2.COLOR_RGB2BGR)

    # alpha plus visible
    alpha = 0.6
    overlay = cv2.addWeighted(original_bgr, 1.0 - alpha, heatmap_colored, alpha, 0)

    # Encoder base64
    _, heatmap_buffer = cv2.imencode('.jpg', heatmap_colored)
    _, overlay_buffer = cv2.imencode('.jpg', overlay)
    return (
        base64.b64encode(heatmap_buffer).decode('utf-8'),
        base64.b64encode(overlay_buffer).decode('utf-8')
    )

# ── PREPROCESSING ─────────────────────────────────────────────────────────────

def preprocess_image(image_bytes: bytes) -> np.ndarray:
    img = Image.open(io.BytesIO(image_bytes)).convert('RGB')
    img = img.resize((224, 224))
    arr = np.array(img, dtype=np.float32)
    arr = tf.keras.applications.efficientnet.preprocess_input(arr)
    return np.expand_dims(arr, axis=0)

# ── ROUTES AUTH ───────────────────────────────────────────────────────────────

@app.post("/auth/register", status_code=201)
def register(user: UserRegister, conn=Depends(get_db)):
    cursor = conn.cursor()
    cursor.execute("SELECT id FROM users WHERE email = %s", (user.email,))
    if cursor.fetchone():
        raise HTTPException(status_code=400, detail="Email déjà utilisé")

    hashed = hash_password(user.password)
    cursor.execute(
        """INSERT INTO users (name, email, phone, speciality, avatar_b64, password)
           VALUES (%s, %s, %s, %s, %s, %s)
           RETURNING id""",
        (user.name, user.email, user.phone, user.speciality, user.avatar_b64, hashed)
    )
    user_id = cursor.fetchone()[0]
    conn.commit()
    token = create_token({"sub": str(user_id)})
    return {"access_token": token, "token_type": "bearer", "user_id": user_id}

@app.post("/auth/login", response_model=Token)
def login(form: OAuth2PasswordRequestForm = Depends(), conn=Depends(get_db)):
    cursor = conn.cursor()
    cursor.execute("SELECT id, password FROM users WHERE email = %s", (form.username,))
    row = cursor.fetchone()
    if not row or not verify_password(form.password, row[1]):
        raise HTTPException(status_code=401, detail="Identifiants incorrects")
    token = create_token({"sub": str(row[0])})
    return {"access_token": token, "token_type": "bearer"}

@app.post("/auth/forgot-password")
def forgot_password(data: ForgotPasswordRequest, conn=Depends(get_db)):
    cursor = conn.cursor()
    cursor.execute("SELECT id FROM users WHERE email = %s", (data.email,))
    row = cursor.fetchone()

    # Réponse volontairement neutre pour éviter l'énumération d'emails.
    if not row:
        return {"message": "Si cet email existe, un lien de réinitialisation a été envoyé."}

    reset_token = create_password_reset_token(row[0])
    return {
        "message": "Token de réinitialisation généré.",
        "reset_token": reset_token
    }

@app.post("/auth/reset-password")
def reset_password(data: ResetPasswordRequest, conn=Depends(get_db)):
    user_id = verify_password_reset_token(data.token)

    cursor = conn.cursor()
    cursor.execute("SELECT id FROM users WHERE id = %s", (user_id,))
    if not cursor.fetchone():
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    cursor.execute(
        "UPDATE users SET password = %s WHERE id = %s",
        (hash_password(data.new_password), user_id)
    )
    conn.commit()
    return {"message": "Mot de passe réinitialisé avec succès"}

# ── ROUTES SCAN ───────────────────────────────────────────────────────────────

@app.post("/scan/predict")
async def predict(
    file: UploadFile = File(...),
    user_id: int = Depends(get_current_user),
    conn=Depends(get_db)
):
    # Lire et prétraiter l'image
    image_bytes = await file.read()
    img_array   = preprocess_image(image_bytes)

    # Prédiction
    prediction = float(model.predict(img_array)[0][0])
    label      = "PNEUMONIA" if prediction > 0.5 else "NORMAL"
    confidence = prediction if prediction > 0.5 else 1 - prediction

    # Grad-CAM: si NORMAL avec très haute confiance, ne pas afficher de hotspot chaud
    if label == "NORMAL" and confidence >= 0.85:
        # créer un overlay légèrement bleuté sans hotspots
        original_img = Image.open(io.BytesIO(image_bytes)).convert('RGB').resize((224, 224))
        orig_np = np.array(original_img, dtype=np.uint8)
        orig_bgr = cv2.cvtColor(orig_np, cv2.COLOR_RGB2BGR)
        blue_tint = np.full_like(orig_bgr, (255, 0, 0))  # BGR blue
        overlay_img = cv2.addWeighted(orig_bgr, 0.9, blue_tint, 0.1, 0)
        empty_heatmap = np.zeros((224, 224), dtype=np.uint8)

        _, heatmap_buffer = cv2.imencode('.jpg', cv2.applyColorMap(empty_heatmap, cv2.COLORMAP_OCEAN))
        _, overlay_buffer = cv2.imencode('.jpg', overlay_img)
        heatmap_b64 = base64.b64encode(heatmap_buffer).decode('utf-8')
        overlay_b64 = base64.b64encode(overlay_buffer).decode('utf-8')
    else:
        heatmap_b64, overlay_b64 = generate_gradcam(img_array, image_bytes)

    # Image originale en base64
    image_b64 = base64.b64encode(image_bytes).decode('utf-8')

    # Sauvegarder dans PostgreSQL
    cursor = conn.cursor()
    cursor.execute(
        """INSERT INTO scans (user_id, label, confidence, image_b64, heatmap_b64)
           VALUES (%s, %s, %s, %s, %s) RETURNING id""",
        (user_id, label, round(confidence * 100, 2), image_b64, heatmap_b64)
    )
    scan_id = cursor.fetchone()[0]
    conn.commit()

    return {
        "scan_id":    scan_id,
        "label":      label,
        "confidence": round(confidence * 100, 2),
        "image_b64":  image_b64,
        "heatmap":    heatmap_b64,
        "overlay":    overlay_b64
    }

# ── ROUTES HISTORIQUE ─────────────────────────────────────────────────────────

@app.get("/history")
def get_history(user_id: int = Depends(get_current_user), conn=Depends(get_db)):
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cursor.execute(
        """SELECT id, label, confidence, image_b64, heatmap_b64, created_at
        FROM scans WHERE user_id = %s ORDER BY created_at DESC""",
        (user_id,)
    )
    rows = cursor.fetchall()
    return {"history": [dict(r) for r in rows]}

@app.delete("/history/{scan_id}")
def delete_scan(
    scan_id: int,
    user_id: int = Depends(get_current_user),
    conn=Depends(get_db)
):
    cursor = conn.cursor()
    cursor.execute(
        "DELETE FROM scans WHERE id = %s AND user_id = %s",
        (scan_id, user_id)
    )
    conn.commit()
    if cursor.rowcount == 0:
        raise HTTPException(status_code=404, detail="Scan introuvable")
    return {"message": "Scan supprimé"}

# ── ROUTES STATISTIQUES ───────────────────────────────────────────────────────

@app.get("/stats")
def get_stats(user_id: int = Depends(get_current_user), conn=Depends(get_db)):
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # Total et répartition
    cursor.execute(
        """SELECT
             COUNT(*) as total,
             SUM(CASE WHEN label='NORMAL' THEN 1 ELSE 0 END) as normal_count,
             SUM(CASE WHEN label='PNEUMONIA' THEN 1 ELSE 0 END) as pneumonia_count,
             ROUND(AVG(CASE WHEN label='NORMAL' THEN confidence END)::numeric, 2) as avg_conf_normal,
             ROUND(AVG(CASE WHEN label='PNEUMONIA' THEN confidence END)::numeric, 2) as avg_conf_pneumonia
           FROM scans WHERE user_id = %s""",
        (user_id,)
    )
    summary = dict(cursor.fetchone())

    # Évolution sur 30 jours
    cursor.execute(
        """SELECT DATE(created_at) as date, COUNT(*) as count
           FROM scans
           WHERE user_id = %s AND created_at >= NOW() - INTERVAL '30 days'
           GROUP BY DATE(created_at)
           ORDER BY date""",
        (user_id,)
    )
    timeline = [dict(r) for r in cursor.fetchall()]

    return {"summary": summary, "timeline": timeline}

# ── ROUTES PROFIL ─────────────────────────────────────────────────────────────

@app.get("/profile")
def get_profile(user_id: int = Depends(get_current_user), conn=Depends(get_db)):
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cursor.execute(
        """SELECT id, name, email, phone, speciality, avatar_b64, created_at
           FROM users WHERE id = %s""",
        (user_id,)
    )
    user = cursor.fetchone()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return dict(user)


class UserUpdate(BaseModel):
    name:       str | None = None
    email:      EmailStr | None = None
    phone:      str | None = None
    speciality: str | None = None
    avatar_b64: str | None = None


@app.put("/profile")
def update_profile(
    data: UserUpdate,
    user_id: int = Depends(get_current_user),
    conn=Depends(get_db)
):
    cursor = conn.cursor()

    fields = []
    values = []

    if data.name is not None:
        fields.append("name = %s")
        values.append(data.name)
    if data.email is not None:
        cursor.execute(
            "SELECT id FROM users WHERE email = %s AND id <> %s",
            (data.email, user_id)
        )
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="Email déjà utilisé")
        fields.append("email = %s")
        values.append(data.email)
    if data.phone is not None:
        fields.append("phone = %s")
        values.append(data.phone)
    if data.speciality is not None:
        fields.append("speciality = %s")
        values.append(data.speciality)
    if data.avatar_b64 is not None:
        fields.append("avatar_b64 = %s")
        values.append(data.avatar_b64)

    if not fields:
        raise HTTPException(status_code=400, detail="Aucune donnée à mettre à jour")

    values.append(user_id)
    cursor.execute(
        f"UPDATE users SET {', '.join(fields)} WHERE id = %s",
        values
    )
    conn.commit()
    return {"message": "Profil mis à jour"}


@app.put("/profile/password")
def update_password(
    old_password: str,
    new_password: str,
    user_id: int = Depends(get_current_user),
    conn=Depends(get_db)
):
    cursor = conn.cursor()
    cursor.execute("SELECT password FROM users WHERE id = %s", (user_id,))
    row = cursor.fetchone()
    if not row or not verify_password(old_password, row[0]):
        raise HTTPException(status_code=401, detail="Ancien mot de passe incorrect")

    cursor.execute(
        "UPDATE users SET password = %s WHERE id = %s",
        (hash_password(new_password), user_id)
    )
    conn.commit()
    return {"message": "Mot de passe mis à jour"}

# ── LANCEMENT ─────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)