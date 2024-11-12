#!/bin/bash

# Variables
APP_NAME="aenzbi-global"
DB_NAME="aenzbi_db"
DB_USER="aenzbi_user"
DB_PASSWORD="AenzbiSecurePass2024!"
PROJECT_ID="aenzbi-global-platform"
REGION="us-central1"
GIT_REPO="https://github.com/allyelvis/$APP_NAME.git"  # Replace with your GitHub repository URL

# Colors for messages
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display success messages
success_message() {
    echo -e "${GREEN}$1${NC}"
}

# Function to display error messages
error_message() {
    echo -e "${RED}$1${NC}"
    exit 1
}

# Step 1: Install dependencies
echo "Installing necessary dependencies..."
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y git curl nodejs npm postgresql postgresql-contrib python3-pip || error_message "Failed to install dependencies!"

# Step 2: Install Google Cloud SDK if not installed
echo "Installing Google Cloud SDK..."
if ! command -v gcloud &> /dev/null
then
    curl https://sdk.cloud.google.com | bash
    exec -l $SHELL
    gcloud init || error_message "Failed to install and initialize Google Cloud SDK!"
else
    success_message "Google Cloud SDK is already installed."
fi

# Step 3: Set up project directories and files
echo "Setting up project structure..."
mkdir -p ~/$APP_NAME/{backend,frontend,api,db,scripts}

# Backend setup
echo "Initializing Node.js backend API..."
cd ~/$APP_NAME/api
npm init -y
npm install express pg dotenv body-parser --save

# Create a basic Express API server
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

# Step 4: Set up environment variables
echo "Creating environment variables for API..."
cat > .env <<EOL
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_NAME=$DB_NAME
EOL

# Step 5: Set up PostgreSQL database and schema
echo "Setting up PostgreSQL database..."
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"

cat > ~/$APP_NAME/db/schema.sql <<EOL
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

# Apply schema
sudo -u postgres psql -d $DB_NAME -f ~/$APP_NAME/db/schema.sql

# Step 6: Set up Firebase Hosting and Google Cloud Deployment
echo "Setting up Firebase Hosting and Google Cloud Deployment..."
npm install -g firebase-tools
firebase login
firebase init hosting || error_message "Firebase setup failed!"

gcloud projects create $PROJECT_ID --set-as-default
gcloud config set project $PROJECT_ID
gcloud app create --region=$REGION || error_message "Google Cloud project setup failed!"

# Create app.yaml for Google App Engine deployment
cat > app.yaml <<EOL
runtime: nodejs14

env_variables:
  DB_USER: $DB_USER
  DB_PASSWORD: $DB_PASSWORD
  DB_NAME: $DB_NAME
EOL

# Deploy API to Google Cloud
gcloud app deploy -q || error_message "Failed to deploy API to Google Cloud!"

# Step 7: Initialize Git repository and push to GitHub
echo "Initializing Git repository..."
cd ~/$APP_NAME
git init
git remote add origin $GIT_REPO
git add .
git commit -m "Initial project setup for Aenzbi Global"
git push -u origin master || error_message "Failed to push to GitHub!"

# Step 8: Final success message
success_message "Aenzbi Global Business Management Platform has been set up successfully!"
echo "API is deployed on Google Cloud and code is pushed to GitHub."