from app.utils.jwt_utils import generate_token

# Generate a JWT token for student_id 1
token = generate_token(student_id=1, email="student@example.com")
print("Here is your JWT token:\n")
print(token)