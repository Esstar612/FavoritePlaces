import logging

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth

from outing_agent.config import CHECK_REVOKED
from outing_agent.firebase_app import get_firebase_app

log = logging.getLogger(__name__)

# auto_error=False so every failure gets the same bare 401.
_bearer = HTTPBearer(auto_error=False)

_TOKEN_ERRORS = (auth.InvalidIdTokenError, auth.UserDisabledError, auth.UserNotFoundError, ValueError)


def _unauthorized() -> HTTPException:
    return HTTPException(
        status.HTTP_401_UNAUTHORIZED,
        detail="Unauthorized",
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_verified_uid(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> str:
    if credentials is None:
        raise _unauthorized()
    # Outside the try so a misconfigured server is a 500, not a bad token.
    app = get_firebase_app()
    try:
        decoded = auth.verify_id_token(
            credentials.credentials, app=app, check_revoked=CHECK_REVOKED
        )
    except auth.CertificateFetchError:
        log.error("could not fetch Firebase public keys to verify an ID token")
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE, detail="Service Unavailable"
        ) from None
    except _TOKEN_ERRORS as error:
        log.info("rejected ID token: %s", type(error).__name__)
        raise _unauthorized() from None
    uid = decoded.get("uid")
    if not isinstance(uid, str) or not uid:
        raise _unauthorized()
    return uid
