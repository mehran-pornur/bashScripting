#!/bin/bash

# List of URLs to check
urls=("https://www.example.com" "https://www.google.com" "https://www.openai.com")  # Add your desired URLs to the list

# Email notification settings
recipient="youremail@example.com"  # Replace with the recipient email address
sender="sender@example.com"  # Replace with the sender email address
smtp_server="smtp.example.com"  # Replace with the SMTP server address
smtp_port="587"  # Replace with the SMTP server port
smtp_user="sender@example.com"  # Replace with the SMTP server username
smtp_password="password"  # Replace with the SMTP server password

# Function to send email notification
send_email() {
    subject="Website Down"
    body="The following websites are down:\n\n$1"
    echo -e "$body" | mailx -s "$subject" -r "$sender" -S smtp="$smtp_server:$smtp_port" -S smtp-use-starttls -S smtp-auth=login -S smtp-auth-user="$smtp_user" -S smtp-auth-password="$smtp_password" "$recipient"
}

# Main script

down_urls=""

# Check the status of each URL
for url in "${urls[@]}"; do
    response=$(curl -Is "$url" | head -n 1)
    if [[ ! $response =~ "200 OK" ]]; then
        down_urls+="$url\n"
    fi
done

# Send email notification if any URLs are down
if [[ -n $down_urls ]]; then
    send_email "$down_urls"
    echo "Email notification sent."
else
    echo "All websites are up."
fi
