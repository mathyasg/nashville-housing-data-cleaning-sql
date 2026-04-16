-- =============================================
-- PORTFOLIO PROJECT: Nashville Housing Data Cleaning
-- Author: Mathyas Tilahun
-- Date: April 2026
-- SQL Server 
-- =============================================

USE PortfolioProject;
GO

-- 1. BACKUP: Work on a clean copy so original data is safe
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'housing_data_cleaned')
    SELECT * INTO housing_data_cleaned 
    FROM NashvilleHousing;

-- 2. Add & Convert SaleDate to proper DATE format
ALTER TABLE housing_data_cleaned
ADD SaleDateConverted DATE;

UPDATE housing_data_cleaned
SET SaleDateConverted = TRY_CONVERT(DATE, SaleDate);

SELECT SaleDate, SaleDateConverted, COUNT(*) AS row_count
FROM housing_data_cleaned
GROUP BY SaleDate, SaleDateConverted
ORDER BY SaleDateConverted;

-- 3. Populate missing PropertyAddress using self-join on ParcelID
UPDATE a
SET a.PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM housing_data_cleaned a
JOIN housing_data_cleaned b
    ON a.ParcelID = b.ParcelID
    AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress IS NULL;

-- Verification
SELECT COUNT(*) AS missing_property_address 
FROM housing_data_cleaned 
WHERE PropertyAddress IS NULL;

-- 4. Split PropertyAddress into Address & City
ALTER TABLE housing_data_cleaned
ADD SplitPropertyAddress NVARCHAR(255),
    SplitPropertyCity NVARCHAR(255);

UPDATE housing_data_cleaned
SET SplitPropertyAddress = TRIM(SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1)),
    SplitPropertyCity     = TRIM(SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress)));

-- 5. Split OwnerAddress using PARSENAME (replacing comma with period first)
ALTER TABLE housing_data_cleaned
ADD SplitOwnerAddress NVARCHAR(255),
    SplitOwnerCity NVARCHAR(255),
    SplitOwnerState NVARCHAR(255);

UPDATE housing_data_cleaned
SET SplitOwnerAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3),
    SplitOwnerCity    = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2),
    SplitOwnerState   = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1);

-- 6. Standardize SoldAsVacant (Y/N → Yes/No)
UPDATE housing_data_cleaned
SET SoldAsVacant = CASE 
    WHEN SoldAsVacant = 'Y' THEN 'Yes'
    WHEN SoldAsVacant = 'N' THEN 'No'
    ELSE SoldAsVacant 
END;

-- Verification
SELECT DISTINCT SoldAsVacant, COUNT(*) AS count
FROM housing_data_cleaned
GROUP BY SoldAsVacant;

-- 7. Remove duplicates using CTE
WITH RowNumCTE AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference
            ORDER BY UniqueID
        ) AS row_num
    FROM housing_data_cleaned
)
DELETE FROM RowNumCTE
WHERE row_num > 1;

-- Verification (should return 0 rows)
WITH RowNumCTE AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference
            ORDER BY UniqueID
        ) AS row_num
    FROM housing_data_cleaned
)
SELECT * FROM RowNumCTE WHERE row_num > 1;

-- 8. (Optional) Add indexes for faster future queries
CREATE NONCLUSTERED INDEX idx_parcelid ON housing_data_cleaned(ParcelID);
CREATE NONCLUSTERED INDEX idx_saledate ON housing_data_cleaned(SaleDateConverted);

-- 9. Drop altered columns columns
ALTER TABLE housing_data_cleaned
DROP COLUMN OwnerAddress, PropertyAddress, SaleDate;

-- FINAL: View the cleaned table
SELECT TOP 100 * FROM housing_data_cleaned ORDER BY SaleDateConverted DESC;

-- Business-ready summary queries (add these to your README)
SELECT 
    YEAR(SaleDateConverted) AS SaleYear,
    COUNT(*) AS TotalSales,
    FORMAT(AVG(SalePrice),'N2') AS AvgSalePrice,
    FORMAT(MAX(SalePrice), 'N0') AS HighestSale
FROM housing_data_cleaned
GROUP BY YEAR(SaleDateConverted)
ORDER BY SaleYear;