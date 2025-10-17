use serde::{Deserialize, Serialize};

#[derive(Deserialize, Debug)]
pub struct RegisterUser {
    pub email: String,
    pub password: String,
    pub first_name: String,
    pub last_name: String,
    pub phone: String,
    pub citizen_id: String,
    #[serde(default)]
    pub role: Option<String>,
    #[serde(default)]
    pub hn: Option<String>,
    #[serde(default)]
    pub mln: Option<String>,
}

#[derive(Deserialize)]
pub struct LoginUser {
    pub email: String,
    pub password: String,
    #[serde(default)]
    pub role: Option<String>,
}

#[derive(Serialize)]
pub struct Token {
    pub token: String,
    pub role: String,
}
