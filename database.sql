-- NOTE: This application uses Firebase Firestore (NoSQL). 
-- Below is a conceptual SQL representation of the data structure for reference.

CREATE TABLE users (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255),
    email VARCHAR(255) UNIQUE,
    role ENUM('STUDENT', 'PROGRAM HEAD', 'DEAN', 'ADMIN'),
    department VARCHAR(255),
    createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE evaluations (
    evaluationId VARCHAR(255) PRIMARY KEY,
    teacherId VARCHAR(255),
    evaluatorId VARCHAR(255),
    role VARCHAR(50),
    weightedScore DECIMAL(5, 2),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (teacherId) REFERENCES users(id),
    FOREIGN KEY (evaluatorId) REFERENCES users(id)
);

CREATE TABLE audit_logs (
    logId VARCHAR(255) PRIMARY KEY,
    title VARCHAR(255),
    details TEXT,
    role VARCHAR(50),
    type VARCHAR(50), -- e.g., EVALUATION, EXPORT, REMINDER
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE rooms (
    roomId VARCHAR(255) PRIMARY KEY,
    roomName VARCHAR(255),
    building VARCHAR(255),
    capacity INT
);

CREATE TABLE support_tickets (
    ticketId VARCHAR(255) PRIMARY KEY,
    userId VARCHAR(255),
    subject VARCHAR(255),
    message TEXT,
    status ENUM('OPEN', 'CLOSED', 'PENDING'),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (userId) REFERENCES users(id)
);
