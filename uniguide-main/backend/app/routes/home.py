# app/routes/home.py
from flask import Blueprint

# Define the blueprint
home_bp = Blueprint("home", __name__)

@home_bp.route("/", methods=["GET"])
def home():
    return "UniGuide backend is running! Visit /chat/ to ask questions."