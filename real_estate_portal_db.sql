DROP DATABASE IF EXISTS real_estate_portal_db;
CREATE DATABASE real_estate_portal_db;
USE real_estate_portal_db;

CREATE TABLE Users (
    userId INT NOT NULL UNIQUE AUTO_INCREMENT,
    userName VARCHAR(50) NOT NULL UNIQUE,
    contactInfo VARCHAR(200),
    passwordHash VARCHAR(255) NOT NULL,
    userType ENUM('agent', 'buyer', 'renter') NOT NULL,
    PRIMARY KEY (userId)
);

CREATE TABLE Properties (
    propertyId INT NOT NULL UNIQUE AUTO_INCREMENT,
    title VARCHAR(100) NOT NULL,
    propertyType VARCHAR(50) NOT NULL,
    address VARCHAR(200) NOT NULL,
    city VARCHAR(100) NOT NULL,
    price DECIMAL(12,2) NOT NULL,
    status ENUM('available', 'sold', 'rented') NOT NULL DEFAULT 'available',
    agentId INT NOT NULL,
    PRIMARY KEY (propertyId),
    CONSTRAINT fk_properties_agent
        FOREIGN KEY (agentId) REFERENCES Users(userId)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

CREATE TABLE Inquiries (
    inquiryId INT NOT NULL UNIQUE AUTO_INCREMENT,
    userId INT NOT NULL,
    propertyId INT NOT NULL,
    message VARCHAR(255) NOT NULL,
    createdAt DATETIME NOT NULL,
    PRIMARY KEY (inquiryId),
    CONSTRAINT fk_inquiries_user
        FOREIGN KEY (userId) REFERENCES Users(userId)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_inquiries_property
        FOREIGN KEY (propertyId) REFERENCES Properties(propertyId)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE Transactions (
    transactionId INT NOT NULL UNIQUE AUTO_INCREMENT,
    propertyId INT NOT NULL,
    userId INT NOT NULL,
    transactionType ENUM('sale', 'rental') NOT NULL,
    transactionDate DATETIME NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (transactionId),
    CONSTRAINT fk_transactions_property
        FOREIGN KEY (propertyId) REFERENCES Properties(propertyId)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_transactions_user
        FOREIGN KEY (userId) REFERENCES Users(userId)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

CREATE TABLE Favorites (
    favoriteId INT NOT NULL UNIQUE AUTO_INCREMENT,
    userId INT NOT NULL,
    propertyId INT NOT NULL,
    savedDate DATETIME NOT NULL,
    PRIMARY KEY (favoriteId),
    CONSTRAINT fk_favorites_user
        FOREIGN KEY (userId) REFERENCES Users(userId)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_favorites_property
        FOREIGN KEY (propertyId) REFERENCES Properties(propertyId)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT uq_user_property_favorite UNIQUE (userId, propertyId)
);

DELIMITER $$

CREATE PROCEDURE AddOrUpdateUser(
    IN p_userId INT,
    IN p_userName VARCHAR(50),
    IN p_contactInfo VARCHAR(200),
    IN p_passwordHash VARCHAR(255),
    IN p_userType ENUM('agent', 'buyer', 'renter')
)
BEGIN
    IF p_userId IS NULL OR p_userId = 0 THEN
        INSERT INTO Users(userName, contactInfo, passwordHash, userType)
        VALUES(p_userName, p_contactInfo, p_passwordHash, p_userType);
    ELSE
        UPDATE Users
        SET userName = p_userName,
            contactInfo = p_contactInfo,
            passwordHash = p_passwordHash,
            userType = p_userType
        WHERE userId = p_userId;
    END IF;
END$$

CREATE PROCEDURE ProcessTransaction(
    IN p_propertyId INT,
    IN p_userId INT,
    IN p_transactionType ENUM('sale', 'rental'),
    IN p_amount DECIMAL(12,2)
)
BEGIN
    INSERT INTO Transactions(propertyId, userId, transactionType, transactionDate, amount)
    VALUES(p_propertyId, p_userId, p_transactionType, NOW(), p_amount);

    UPDATE Properties
    SET status = CASE
        WHEN p_transactionType = 'sale' THEN 'sold'
        WHEN p_transactionType = 'rental' THEN 'rented'
        ELSE status
    END
    WHERE propertyId = p_propertyId;
END$$

CREATE TRIGGER AfterTransactionInsert
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    UPDATE Properties
    SET status = CASE
        WHEN NEW.transactionType = 'sale' THEN 'sold'
        WHEN NEW.transactionType = 'rental' THEN 'rented'
        ELSE status
    END
    WHERE propertyId = NEW.propertyId;
END$$

DELIMITER ;

CREATE VIEW PropertyListingView AS
SELECT
    p.propertyId,
    p.title,
    p.propertyType,
    p.city,
    p.price,
    p.status,
    u.userName AS agentName
FROM Properties p
JOIN Users u ON p.agentId = u.userId;

INSERT INTO Users(userName, contactInfo, passwordHash, userType) VALUES
('agent_john', 'john.agent@example.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC0B3iJ6UfTupfy', 'agent'),
('buyer_maria', 'maria.buyer@example.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC0B3iJ6UfTupfy', 'buyer'),
('renter_ali', 'ali.renter@example.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC0B3iJ6UfTupfy', 'renter');

INSERT INTO Properties(title, propertyType, address, city, price, status, agentId) VALUES
('Modern Family House', 'House', '123 Maple Street', 'Bronx', 650000.00, 'available', 1),
('Downtown Apartment', 'Apartment', '45 Main Avenue', 'New York', 2800.00, 'available', 1),
('Queens Condo', 'Condo', '88 Queens Blvd', 'Queens', 420000.00, 'available', 1);

INSERT INTO Inquiries(userId, propertyId, message, createdAt) VALUES
(2, 1, 'I am interested in buying this house. Can I schedule a showing?', NOW()),
(3, 2, 'Is this apartment available for rent next month?', NOW()),
(2, 3, 'Can you send more details about the condo fees?', NOW());

INSERT INTO Favorites(userId, propertyId, savedDate) VALUES
(2, 1, NOW()),
(2, 3, NOW()),
(3, 2, NOW());

CALL ProcessTransaction(1, 2, 'sale', 650000.00);
CALL ProcessTransaction(2, 3, 'rental', 2800.00);
CALL ProcessTransaction(3, 2, 'sale', 420000.00);

