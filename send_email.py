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

# This code grabs the first command-line argument passed to the script (sys.argv[1]) and stores it in the csv_file variable. This allows the script to dynamically accept different CSV file paths when running the script.
csv_file = sys.argv[1]

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
with open(csv_file, "rb") as attachment:
    part = MIMEBase("application", "octet-stream")
    part.set_payload(attachment.read())
    encoders.encode_base64(part)
    part.add_header("Content-Disposition", f"attachment; filename={csv_file}")
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


