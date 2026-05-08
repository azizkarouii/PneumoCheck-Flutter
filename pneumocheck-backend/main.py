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

def generate_gradcam(img_array: np.ndarray) -> str:
    # Trouver la dernière couche Conv2D dans EfficientNetB0
    efficientnet = model.layers[0]
    last_conv_layer_name = None
    for layer in efficientnet.layers:
        if isinstance(layer, tf.keras.layers.Conv2D):
            last_conv_layer_name = layer.name

    # Construire le grad model depuis les inputs du modèle séquentiel
    grad_model = tf.keras.models.Model(
        inputs=efficientnet.input,
        outputs=[
            efficientnet.get_layer(last_conv_layer_name).output,
            efficientnet.output
        ]
    )

    with tf.GradientTape() as tape:
        conv_outputs, predictions = grad_model(img_array)
        # Passer dans la tête de classification
        x = conv_outputs
        loss = predictions[:, 0]

    grads   = tape.gradient(loss, conv_outputs)
    pooled  = tf.reduce_mean(grads, axis=(0, 1, 2))
    heatmap = conv_outputs[0] @ pooled[..., tf.newaxis]
    heatmap = tf.squeeze(heatmap).numpy()
    heatmap = np.maximum(heatmap, 0)
    if heatmap.max() != 0:
        heatmap = heatmap / heatmap.max()

    # Redimensionner et coloriser
    heatmap_resized = cv2.resize(heatmap, (224, 224))
    heatmap_colored = cv2.applyColorMap(
        np.uint8(255 * heatmap_resized), cv2.COLORMAP_JET
    )

    # Superposer sur l'image originale
    original = img_array[0]
    original = (original - original.min()) / (original.max() - original.min())
    original = np.uint8(255 * original)
    superimposed = cv2.addWeighted(original, 0.6, heatmap_colored, 0.4, 0)

    # Encoder en base64
    _, buffer = cv2.imencode('.jpg', superimposed)
    return base64.b64encode(buffer).decode('utf-8')

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

    # Grad-CAM
    heatmap_b64 = generate_gradcam(img_array)

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
        "heatmap":    heatmap_b64
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