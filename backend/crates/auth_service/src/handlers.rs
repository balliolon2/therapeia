use axum::{Json, extract::State, http::StatusCode};
use bcrypt::{DEFAULT_COST, hash};
use common::config::AppConfig;
use jsonwebtoken::{EncodingKey, Header, encode};
use sqlx::PgPool;

use super::models::{LoginUser, RegisterUser, Token};

pub async fn register(
    State((db, cfg)): State<(PgPool, AppConfig)>,
    Json(payload): Json<RegisterUser>,
) -> Result<(StatusCode, Json<Token>), (StatusCode, String)> {
    println!("Registering user: {:?}", payload);
    let RegisterUser {
        email,
        password,
        first_name,
        last_name,
        phone,
        citizen_id,
        role,
        hn,
        mln,
    } = payload;

    let hashed_password = match hash(password, DEFAULT_COST) {
        Ok(h) => h,
        Err(_) => {
            return Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to hash password".to_string(),
            ));
        }
    };

    let user_id = sqlx::query_scalar!(
        "INSERT INTO users (email, password, first_name, last_name, phone, citizen_id) VALUES ($1, $2, $3, $4, $5, $6) RETURNING user_id",
        email,
        hashed_password,
        first_name,
        last_name,
        phone,
        citizen_id
    )
    .fetch_one(&db)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let role = role
        .as_deref()
        .map(|value| value.trim().to_uppercase())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "PATIENT".to_string());

    if !matches!(role.as_str(), "PATIENT" | "DOCTOR") {
        return Err((StatusCode::BAD_REQUEST, "Invalid role".to_string()));
    }

    sqlx::query(
        "INSERT INTO user_roles (user_id, role) VALUES ($1, $2::role_type) ON CONFLICT (user_id, role) DO NOTHING",
    )
    .bind(user_id)
    .bind(role.as_str())
    .execute(&db)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    match role.as_str() {
        "PATIENT" => {
            if let Some(hn_raw) = hn
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
            {
                let hn_value: i32 = hn_raw.parse().map_err(|_| {
                    (
                        StatusCode::BAD_REQUEST,
                        "Hospital number must be numeric".to_string(),
                    )
                })?;
                sqlx::query!(
                    "INSERT INTO patient_profile (user_id, hn) VALUES ($1, $2) ON CONFLICT (user_id) DO NOTHING",
                    user_id,
                    hn_value
                )
                .execute(&db)
                .await
                .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
            }
        }
        "DOCTOR" => {
            if let Some(mln_raw) = mln
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
            {
                sqlx::query!(
                    "INSERT INTO doctor_profile (user_id, mln) VALUES ($1, $2) ON CONFLICT (user_id) DO NOTHING",
                    user_id,
                    mln_raw
                )
                .execute(&db)
                .await
                .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
            }
        }
        _ => {}
    }

    let claims = serde_json::json!({
        "sub": user_id.to_string(),
        "exp": (chrono::Utc::now() + chrono::Duration::days(1)).timestamp(),
    });

    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(cfg.jwt_secret.as_ref()),
    )
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok((StatusCode::CREATED, Json(Token { token, role })))
}

pub async fn login(
    State((db, cfg)): State<(PgPool, AppConfig)>,
    Json(payload): Json<LoginUser>,
) -> Result<(StatusCode, Json<Token>), (StatusCode, String)> {
    let LoginUser {
        email,
        password,
        role,
    } = payload;

    let user = sqlx::query!(
        "SELECT user_id, password FROM users WHERE email = $1",
        email
    )
    .fetch_optional(&db)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
    .ok_or_else(|| (StatusCode::UNAUTHORIZED, "Invalid credentials".to_string()))?;

    let valid = bcrypt::verify(password, &user.password).map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to verify password".to_string(),
        )
    })?;

    if !valid {
        return Err((StatusCode::UNAUTHORIZED, "Invalid credentials".to_string()));
    }

    let roles = sqlx::query!(
        "SELECT role::text as \"role!\" FROM user_roles WHERE user_id = $1 ORDER BY role",
        user.user_id
    )
    .fetch_all(&db)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    if roles.is_empty() {
        return Err((
            StatusCode::FORBIDDEN,
            "No roles assigned to user".to_string(),
        ));
    }

    let requested_role = role
        .as_deref()
        .map(|value| value.trim().to_uppercase())
        .filter(|value| !value.is_empty());

    let selected_role = if let Some(requested) = requested_role {
        if roles.iter().any(|record| record.role == requested) {
            requested
        } else {
            return Err((
                StatusCode::FORBIDDEN,
                "Role not assigned to user".to_string(),
            ));
        }
    } else if roles.len() == 1 {
        roles[0].role.clone()
    } else if let Some(patient_role) = roles.iter().find(|record| record.role == "PATIENT") {
        patient_role.role.clone()
    } else {
        roles[0].role.clone()
    };

    let claims = serde_json::json!({
        "sub": user.user_id.to_string(),
        "exp": (chrono::Utc::now() + chrono::Duration::days(1)).timestamp(),
    });

    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(cfg.jwt_secret.as_ref()),
    )
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok((
        StatusCode::OK,
        Json(Token {
            token,
            role: selected_role,
        }),
    ))
}
