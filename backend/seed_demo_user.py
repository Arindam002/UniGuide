import os
import sqlite3

from dotenv import load_dotenv
from werkzeug.security import generate_password_hash


BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(BACKEND_DIR, ".env"))

from database.db import get_connection, get_db_path


def seed_demo_user():
    email = os.getenv("DEMO_EMAIL", "").strip()
    password = os.getenv("DEMO_PASSWORD", "")
    if not email or not password:
        raise RuntimeError("Both DEMO_EMAIL and DEMO_PASSWORD must be set.")

    db_path = get_db_path()
    if not os.path.isfile(db_path):
        raise RuntimeError(f"Required SQLite database is missing: {db_path}")

    connection = get_connection()
    try:
        existing = connection.execute(
            "SELECT id FROM students WHERE email = ?",
            (email,),
        ).fetchone()
        if existing:
            print("Demo student already exists; no changes made.")
            return

        connection.execute(
            "INSERT INTO students (name, email, password) VALUES (?, ?, ?)",
            ("Demo User", email, generate_password_hash(password)),
        )
        connection.commit()
        print("Demo student created.")
    except sqlite3.Error as exc:
        connection.rollback()
        raise RuntimeError(f"Could not seed demo student: {exc}") from exc
    finally:
        connection.close()


if __name__ == "__main__":
    seed_demo_user()