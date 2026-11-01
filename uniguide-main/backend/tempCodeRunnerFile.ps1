# ------------------------------
# Backend Testing Script - PowerShell
# ------------------------------

$BASE_URL = "http://127.0.0.1:5000"

# 1. Signup
Write-Host "----- Signup -----"
$SIGNUP_RESPONSE = Invoke-RestMethod -Uri "$BASE_URL/signup" -Method POST -Body (@{
    name="John Doe"
    email="john@example.com"
    password="StrongPass123"
    branch="CSE"
    year="6"
} | ConvertTo-Json) -ContentType "application/json"
$SIGNUP_RESPONSE | ConvertTo-Json
Write-Host ""

# 2. Login
Write-Host "----- Login -----"
$LOGIN_RESPONSE = Invoke-RestMethod -Uri "$BASE_URL/login" -Method POST -Body (@{
    email="john@example.com"
    password="StrongPass123"
} | ConvertTo-Json) -ContentType "application/json"

$TOKEN = $LOGIN_RESPONSE.token
Write-Host "JWT Token: $TOKEN"
Write-Host ""

# 3. Get Branches
Write-Host "----- Get Branches -----"
Invoke-RestMethod -Uri "$BASE_URL/get_branches" -Method GET | ConvertTo-Json
Write-Host ""

# 4. Get Semesters
Write-Host "----- Get Semesters -----"
Invoke-RestMethod -Uri "$BASE_URL/get_semesters?branch=CSE" -Method GET | ConvertTo-Json
Write-Host ""

# 5. Get PDFs
Write-Host "----- Get PDFs -----"
Invoke-RestMethod -Uri "$BASE_URL/get_items?category=pyqs&branch=CSE&semester=6" -Method GET -Headers @{Authorization = "Bearer $TOKEN"} | ConvertTo-Json
Write-Host ""

# 6 & 7. View and Download PDFs
Write-Host "----- View PDF -----"
Invoke-WebRequest -Uri "$BASE_URL/view?file_path=backend/data/pyqs/branch/cse/btech-cse-6-sem-compiler-design-0530-may-2024.pdf&category=pyqs&branch=CSE&semester=6" -Headers @{Authorization = "Bearer $TOKEN"} -OutFile "viewed.pdf"
Write-Host "PDF saved as viewed.pdf"
Write-Host ""

Write-Host "----- Download PDF -----"
Invoke-WebRequest -Uri "$BASE_URL/download?file_path=backend/data/pyqs/branch/cse/btech-cse-6-sem-compiler-design-0530-may-2024.pdf&category=pyqs&branch=CSE&semester=6" -Headers @{Authorization = "Bearer $TOKEN"} -OutFile "downloaded.pdf"
Write-Host "PDF saved as downloaded.pdf"
Write-Host ""

# 8. Get Student History
Write-Host "----- Student History -----"
Invoke-RestMethod -Uri "$BASE_URL/history/1" -Method GET -Headers @{Authorization = "Bearer $TOKEN"} | ConvertTo-Json
Write-Host ""

# 9. Forgot Password
Write-Host "----- Forgot Password -----"
$FORGOT_RESPONSE = Invoke-RestMethod -Uri "$BASE_URL/forgot_password" -Method POST -Body (@{email="john@example.com"} | ConvertTo-Json) -ContentType "application/json"
$FORGOT_RESPONSE | ConvertTo-Json
Write-Host "Reset link: $($FORGOT_RESPONSE.reset_link)"
Write-Host ""

Write-Host "✅ Backend testing script completed."