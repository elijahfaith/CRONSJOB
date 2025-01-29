import smtplib
import os
from email.mime.multipart import MIMEMultipart 
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import sys

sender_email = os.getenv("SENDER_EMAIL")
receiver_email = os.getenv("RECEIVER_EMAIL")
subject = "Docker Hub Logs"
body = "Hello,\n\nPlease find attached the Docker Hub logs.\n\nBest regards."

# Get the CSV file path passed from the Bash script
csv_file = sys.argv[1]

# Check if the CSV file exists
if not os.path.exists(csv_file):
    print(f"Error: The file {csv_file} does not exist.")
    sys.exit(1)

# Setting up the SMTP server (Gmail)
smtp_server = "smtp.gmail.com"
smtp_port = 587
password = os.getenv("GMAIL_APP_PASSWORD")

# Create the email
msg = MIMEMultipart()
msg["From"] = sender_email
msg["To"] = receiver_email
msg["Subject"] = subject
msg.attach(MIMEText(body, "plain"))

# Attach the CSV file
filename = os.path.basename(csv_file)  # Extract the file name only
with open(csv_file, "rb") as attachment:
    part = MIMEBase("application", "octet-stream")
    part.set_payload(attachment.read())
    encoders.encode_base64(part)
    part.add_header("Content-Disposition", f"attachment; filename={filename}")
    msg.attach(part)

# Connect to Gmail's SMTP server and send the email
try:
    with smtplib.SMTP(smtp_server, smtp_port) as server:
        server.starttls()  # Upgrade the connection to secure
        server.login(sender_email, password)
        server.sendmail(sender_email, receiver_email, msg.as_string())
        print(f"Email sent successfully to {receiver_email}")
except Exception as e:
    print(f"Failed to send email: {e}")
