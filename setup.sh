#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

# Check if a command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

# Header
echo -e "\n${GREEN}======================================${NC}"
echo -e "${GREEN}       Rephi Project Setup${NC}"
echo -e "${GREEN}======================================${NC}"

# Check required dependencies
print_step "Checking dependencies..."

check_command "elixir"
check_command "mix"
check_command "node"
check_command "yarn"

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 20 ]; then
    print_error "Node.js 20+ is required. Current version: $(node -v)"
    exit 1
fi

print_success "All dependencies found!"

# Check for .env file
print_step "Checking environment configuration..."

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        print_warning ".env file not found. Copying from .env.example..."
        cp .env.example .env
        print_warning "Please review and update .env with your configuration."
    else
        print_warning "No .env or .env.example file found. Skipping..."
    fi
else
    print_success ".env file found!"
fi

# Backend setup
print_step "Installing Elixir dependencies..."
mix deps.get

print_step "Compiling Elixir project..."
mix compile

print_step "Setting up database..."
mix ecto.create || print_warning "Database may already exist, continuing..."
mix ecto.migrate

print_step "Running database seeds..."
mix run priv/repo/seeds.exs || print_warning "Seeds may have already been applied, continuing..."

# Frontend setup
print_step "Installing frontend dependencies..."
yarn install

print_step "Building shared-components package..."
yarn shared:build

# Generate Swagger docs
print_step "Generating API documentation..."
mix phx.swagger.generate || print_warning "Swagger generation skipped or failed, continuing..."

# Summary
echo -e "\n${GREEN}======================================${NC}"
echo -e "${GREEN}       Setup Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo -e "\nTo start the application:"
echo -e "  ${BLUE}1.${NC} Start the backend:  ${YELLOW}mix phx.server${NC}"
echo -e "  ${BLUE}2.${NC} Start the frontend: ${YELLOW}yarn example:dev${NC}"
echo -e "\nEndpoints:"
echo -e "  ${BLUE}-${NC} Backend API:    ${YELLOW}http://localhost:4000/api${NC}"
echo -e "  ${BLUE}-${NC} Swagger UI:     ${YELLOW}http://localhost:4000/api/swagger${NC}"
echo -e "  ${BLUE}-${NC} Frontend (dev): ${YELLOW}http://localhost:5001${NC}"
echo -e "\nDefault admin credentials:"
echo -e "  ${BLUE}-${NC} Email:    ${YELLOW}admin@admin.com${NC}"
echo -e "  ${BLUE}-${NC} Password: ${YELLOW}password123!!${NC}"
echo ""
