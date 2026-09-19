"""
AgriSense AI - Authentication
Handles password hashing and JWT access tokens for account creation & login.

Kept as its own module (like agri_logic.py and diagnosis.py) so the security
logic is easy to review, test, and swap out on its own.
"""

import os
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext

# -----------------------------
# Config
# -----------------------------
# In production, set AGRISENSE_SECRET_KEY as an environment variable instead
# of relying on the fallback below (e.g. in your Render/Railway dashboard).
SECRET_KEY = os.environ.get("AGRISENSE_SECRET_KEY", "agrisense-dev-secret-change-me")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 days - fine for a capstone demo

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Tells FastAPI's /docs page how to send the token, and lets endpoints pull
# the token out of the "Authorization: Bearer <token>" header automatically.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=False)


# -----------------------------
# Password helpers
# -----------------------------
def hash_password(plain_password: str) -> str:
    return pwd_context.hash(plain_password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


# -----------------------------
# Token helpers
# -----------------------------
def create_access_token(subject: str, expires_minutes: int = ACCESS_TOKEN_EXPIRE_MINUTES) -> str:
    """subject is normally the user's email - it's what identifies them inside the token."""
    expire = datetime.now(timezone.utc) + timedelta(minutes=expires_minutes)
    to_encode = {"sub": subject, "exp": expire}
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def decode_access_token(token: str) -> Optional[str]:
    """Returns the subject (email) if the token is valid, otherwise None."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload.get("sub")
    except JWTError:
        return None


# -----------------------------
# FastAPI dependencies
# -----------------------------
# Use `current_email: str = Depends(get_current_user_email)` on any endpoint
# that MUST be logged in - it raises 401 automatically if the token is
# missing or invalid.
def get_current_user_email(token: str = Depends(oauth2_scheme)) -> str:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials. Please log in again.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if token is None:
        raise credentials_exception
    email = decode_access_token(token)
    if email is None:
        raise credentials_exception
    return email
