#!/bin/bash
# Insert ₹1 coupons into database

set -e

echo "Inserting ₹1 coupons into database..."

# Database connection details from .env.local
DB_HOST="13.126.11.184"
DB_PORT="5432"
DB_USER="serveaso"
DB_NAME="serveaso1"
DB_PASS="serveaso"

# Run the SQL file
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f database/sql/114_ondemand_shortterm_1rupee_coupons.sql

echo ""
echo "✅ Successfully inserted ₹1 coupons!"
echo ""
echo "Coupons created:"
echo "  ON-DEMAND:"
echo "    - MAID1-ONDEMAND"
echo "    - COOK1-ONDEMAND"
echo "    - NANNY1-ONDEMAND"
echo ""
echo "  SHORT-TERM:"
echo "    - MAID1-SHORTTERM"
echo "    - COOK1-SHORTTERM"
echo "    - NANNY1-SHORTTERM"
