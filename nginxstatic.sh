#!/bin/bash

# Function to prompt user and read input
get_input() {
    read -p "$1: " input
    echo "$input"
}

# Main Script

# Prompt user for SSH credentials
ssh_username=$(get_input "Enter SSH username")
ssh_host=$(get_input "Enter SSH hostname or IP address")
domain_name=$(get_input "Enter Domain name")
ssh_key=$(get_input "Enter path to SSH key (leave blank for password authentication)")
nginx_server_port=$(get_input "Enter nginx port")
certbot_email=$(get_input "Enter certbot email")


# Construct SSH command
if [ -z "$ssh_key" ]; then
    ssh_command="ssh $ssh_username@$ssh_host"
else
    ssh_command="ssh -p $ssh_port -i $ssh_key $ssh_username@$ssh_host"
fi

# Execute SSH command
echo "Connecting to $ssh_host..."
$ssh_command << EOF
cd /etc/nginx/sites-available/
echo "Enter domain name for new file:"
read domain_name
echo "Creating file for domain: $domain_name"
touch "$domain_name"
echo "Adding nginx server block configuration to $domain_name on port $ssh_port"
cat << 'SERVER_BLOCK' >> "$domain_name"
server {
    server_name $domain_name;
    #THIS IS TO SET STATIC FILES MANUALLY
    location / {
        root /opt/smartgame;
        index index.html;
        proxy_buffering off;
        proxy_set_header X-Real-IP \$remote_addr;    
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
    }
    #microsoft.activeuser.online
    # location / {
    #     # root /opt/\$domain_name;
    #     proxy_pass http://localhost:$nginx_server_port/;
    #     proxy_buffering off;
    #     proxy_set_header X-Real-IP \$remote_addr;
    #     proxy_set_header X-Forwarded-Host \$host;
    #     proxy_set_header X-Forwarded-Port \$server_port;
    # }

    location /socket.io {
        proxy_pass http://localhost:$nginx_server_port;  # Adjust this to your actual socket.io server
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_read_timeout 86400;  # Increase timeout if necessary
    }
}
SERVER_BLOCK

echo "Creating symbolic link.....for $domain_name"
sudo ln -s /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/
echo "Symbolic link Completed..."
echo "Testing Ngix..."
nginx -t
echo "Restarting server..."
sudo systemctl restart nginx
echo "Server restarted..."
echo "...Running CertBot..."
certbot run -n --nginx --agree-tos -d $domain_name  -m  $certbot_email  --redirect
echo "...CertBot completed..."
EOF
