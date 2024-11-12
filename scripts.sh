#!/bin/bash

# Define constants
APP_NAME="aenzbi-global"
DB_NAME="aenzbi_db"
DB_USER="aenzbi_user"
DB_PASSWORD="AenzbiSecurePass2024!"
PROJECT_ID="aenzbi-global-platform"
REGION="us-central1"

# Function to display success messages
success_message() {
  echo -e "\e[32m$1\e[0m"
}

# Function to display error messages
error_message() {
  echo -e "\e[31m$1\e[0m"
  exit 1
}

# Step 1: Update and install necessary dependencies
echo "Updating and installing necessary dependencies..."
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y git curl nodejs npm postgresql postgresql-contrib python3-pip

# Step 2: Install Google Cloud SDK
echo "Installing Google Cloud SDK..."
if ! command -v gcloud &> /dev/null
then
  curl https://sdk.cloud.google.com | bash
  exec -l $SHELL
  gcloud init
else
  success_message "Google Cloud SDK is already installed."
fi

# Step 3: Set up directories and project structure
echo "Setting up project directories..."
mkdir -p ~/projects/$APP_NAME/{backend,frontend,api,db,scripts}
cd ~/projects/$APP_NAME

# Step 4: Initialize Node.js project for API
echo "Initializing Node.js for API..."
cd api
npm init -y
npm install express pg dotenv body-parser --save

# Step 5: Create basic API server
echo "Creating basic Express API server..."
cat > index.js <<EOL
require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const { Pool } = require('pg');

const app = express();
app.use(bodyParser.json());

const pool = new Pool({
  user: process.env.DB_USER,
  host: 'localhost',
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: 5432,
});

app.get('/', (req, res) => {
  res.send('Aenzbi Global API is running!');
});

app.listen(3000, () => {
  console.log('Server is running on port 3000');
});
EOL

# Step 6: Set up environment variables
echo "Setting up environment variables..."
cat > .env <<EOL
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_NAME=$DB_NAME
EOL

# Step 7: Set up PostgreSQL database
echo "Setting up PostgreSQL database..."
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"

# Step 8: Create database schema for products, users, and invoices
echo "Creating database schema..."
cat > ~/projects/$APP_NAME/db/schema.sql <<EOL
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock INT NOT NULL
);

CREATE TABLE IF NOT EXISTS invoices (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    total DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOL

sudo -u postgres psql -d $DB_NAME -f ~/projects/$APP_NAME/db/schema.sql

# Step 9: Deploy API to Google Cloud
echo "Setting up Google Cloud project..."
gcloud projects create $PROJECT_ID --set-as-default
gcloud config set project $PROJECT_ID
gcloud app create --region=$REGION

# Step 10: Deploy API to Google Cloud App Engine
echo "Deploying API to Google Cloud App Engine..."
cat > app.yaml <<EOL
runtime: nodejs14

env_variables:
  DB_USER: $DB_USER
  DB_PASSWORD: $DB_PASSWORD
  DB_NAME: $DB_NAME
EOL

gcloud app deploy -q

# Step 11: Set up Firebase Hosting for frontend (if needed)
echo "Setting up Firebase Hosting..."
npm install -g firebase-tools
firebase login
firebase init hosting
firebase deploy

# Step 12: Output success message
success_message "Aenzbi Global Business Management Platform has been set up successfully!"

echo "To start your API locally, run: cd ~/projects/$APP_NAME/api && node index.json