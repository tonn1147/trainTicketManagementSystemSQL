USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'TrainTicketSystem')
BEGIN
    DROP DATABASE TrainTicketSystem;
END
GO

CREATE DATABASE TrainTicketSystem;
GO

USE TrainTicketSystem;
GO

-- 1.1 Bảng Người dùng
CREATE TABLE Users (
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) UNIQUE,
    PhoneNumber NVARCHAR(20) UNIQUE NOT NULL,
    PasswordHash VARBINARY(64) NOT NULL,
    UserType NVARCHAR(20) CHECK (UserType IN ('Customer', 'Staff', 'Admin')) DEFAULT 'Customer',
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME DEFAULT GETDATE(),
    CONSTRAINT CK_Users_Contact CHECK (Email IS NOT NULL OR PhoneNumber IS NOT NULL)
);


-- 1.3 Bảng Ga tàu
CREATE TABLE Stations (
    StationID INT IDENTITY(1,1) PRIMARY KEY,
    StationCode NVARCHAR(10) UNIQUE NOT NULL,
    StationName NVARCHAR(100) NOT NULL,
    City NVARCHAR(50) NOT NULL,
    Province NVARCHAR(50) NOT NULL,
    Address NVARCHAR(200),
    IsActive BIT DEFAULT 1
);

-- 1.4 Bảng Tuyến tàu
CREATE TABLE Routes (
    RouteID INT IDENTITY(1,1) PRIMARY KEY,
    RouteCode NVARCHAR(20) UNIQUE NOT NULL,
    DepartureStationID INT FOREIGN KEY REFERENCES Stations(StationID),
    ArrivalStationID INT FOREIGN KEY REFERENCES Stations(StationID),
    Distance DECIMAL(8,2), -- km
    EstimatedDuration INT, -- phút
    IsActive BIT DEFAULT 1,
    CONSTRAINT CK_Routes_Different_Stations CHECK (DepartureStationID != ArrivalStationID)
);

-- 1.5 Bảng Đoàn tàu
CREATE TABLE Trains (
    TrainID INT IDENTITY(1,1) PRIMARY KEY,
    TrainCode NVARCHAR(20) UNIQUE NOT NULL,
    TrainName NVARCHAR(100) NOT NULL,
    TrainType NVARCHAR(50), -- SE, TN, SNT, etc.
    TotalCoaches INT NOT NULL,
    IsActive BIT DEFAULT 1
);

-- 1.6 Bảng Hạng ghế
CREATE TABLE SeatClasses (
    SeatClassID INT IDENTITY(1,1) PRIMARY KEY,
    ClassName NVARCHAR(50) UNIQUE NOT NULL, -- Ghế cứng, Ghế mềm, Giường nằm khoang 6, Giường nằm khoang 4
    Description NVARCHAR(200),
    PriceMultiplier DECIMAL(4,2) DEFAULT 1.0 -- Hệ số nhân giá
);

-- 1.7 Bảng Toa tàu
CREATE TABLE Coaches (
    CoachID INT IDENTITY(1,1) PRIMARY KEY,
    TrainID INT FOREIGN KEY REFERENCES Trains(TrainID),
    CoachNumber INT NOT NULL,
    SeatClassID INT FOREIGN KEY REFERENCES SeatClasses(SeatClassID),
    TotalSeats INT NOT NULL,
    CONSTRAINT UQ_Coach_Train_Number UNIQUE (TrainID, CoachNumber)
);

-- 1.8 Bảng Ghế ngồi
CREATE TABLE Seats (
    SeatID INT IDENTITY(1,1) PRIMARY KEY,
    CoachID INT FOREIGN KEY REFERENCES Coaches(CoachID),
    SeatNumber NVARCHAR(10) NOT NULL,
    SeatType NVARCHAR(20) CHECK (SeatType IN ('Lower', 'Upper', 'Middle', 'Single')),
    CONSTRAINT UQ_Seat_Coach_Number UNIQUE (CoachID, SeatNumber)
);

-- 1.9 Bảng Chuyến tàu
CREATE TABLE Schedules (
    ScheduleID INT IDENTITY(1,1) PRIMARY KEY,
    TrainID INT FOREIGN KEY REFERENCES Trains(TrainID),
    RouteID INT FOREIGN KEY REFERENCES Routes(RouteID),
    DepartureTime DATETIME NOT NULL,
    ArrivalTime DATETIME NOT NULL,
    BasePrice DECIMAL(10,2) NOT NULL,
    Status NVARCHAR(20) CHECK (Status IN ('Scheduled', 'Delayed', 'Cancelled', 'Completed')) DEFAULT 'Scheduled',
    AvailableSeats INT,
    CreatedAt DATETIME DEFAULT GETDATE(),
    CONSTRAINT CK_Schedule_Times CHECK (ArrivalTime > DepartureTime)
);

-- 1.10 Bảng Đặt vé
CREATE TABLE Bookings (
    BookingID INT IDENTITY(1,1) PRIMARY KEY,
    BookingCode NVARCHAR(20) UNIQUE NOT NULL,
    UserID INT FOREIGN KEY REFERENCES Users(UserID),
    ScheduleID INT FOREIGN KEY REFERENCES Schedules(ScheduleID),
    BookingDate DATETIME DEFAULT GETDATE(),
    TotalAmount DECIMAL(10,2) NOT NULL,
    PaymentStatus NVARCHAR(20) CHECK (PaymentStatus IN ('Pending', 'Paid', 'Refunded', 'Failed')) DEFAULT 'Pending',
    BookingStatus NVARCHAR(20) CHECK (BookingStatus IN ('Active', 'Cancelled', 'Completed')) DEFAULT 'Active',
    CancelledAt DATETIME,
    CancellationReason NVARCHAR(500)
);

-- 1.11 Bảng Chi tiết vé
CREATE TABLE Tickets (
    TicketID INT IDENTITY(1,1) PRIMARY KEY,
    BookingID INT FOREIGN KEY REFERENCES Bookings(BookingID),
    SeatID INT FOREIGN KEY REFERENCES Seats(SeatID),
    PassengerName NVARCHAR(100) NOT NULL,
    PassengerIDNumber NVARCHAR(20),
    PassengerPhone NVARCHAR(20),
    TicketPrice DECIMAL(10,2) NOT NULL,
    TicketStatus NVARCHAR(20) CHECK (TicketStatus IN ('Valid', 'Used', 'Cancelled', 'Refunded')) DEFAULT 'Valid'
);

-- 1.12 Bảng Thanh toán
CREATE TABLE Payments (
    PaymentID INT IDENTITY(1,1) PRIMARY KEY,
    BookingID INT FOREIGN KEY REFERENCES Bookings(BookingID),
    PaymentMethod NVARCHAR(50) CHECK (PaymentMethod IN ('Momo', 'ZaloPay', 'VNPay', 'Visa', 'MasterCard', 'Cash')),
    TransactionID NVARCHAR(100),
    Amount DECIMAL(10,2) NOT NULL,
    PaymentDate DATETIME DEFAULT GETDATE(),
    PaymentStatus NVARCHAR(20) CHECK (PaymentStatus IN ('Success', 'Failed', 'Pending')) DEFAULT 'Pending',
    ResponseCode NVARCHAR(50),
    ResponseMessage NVARCHAR(500)
);

-- 1.13 Bảng Chính sách hoàn hủy
CREATE TABLE RefundPolicies (
    PolicyID INT IDENTITY(1,1) PRIMARY KEY,
    HoursBeforeDeparture INT NOT NULL,
    RefundPercentage DECIMAL(5,2) NOT NULL, -- % được hoàn
    Description NVARCHAR(200)
);

-- 1.14 Bảng Thông báo
CREATE TABLE Notifications (
    NotificationID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT FOREIGN KEY REFERENCES Users(UserID),
    BookingID INT FOREIGN KEY REFERENCES Bookings(BookingID),
    NotificationType NVARCHAR(50) CHECK (NotificationType IN ('Reminder', 'Cancellation', 'Delay', 'Payment', 'Promotion')),
    Title NVARCHAR(200),
    Message NVARCHAR(1000),
    IsRead BIT DEFAULT 0,
    SentAt DATETIME DEFAULT GETDATE(),
    ScheduledFor DATETIME
);

GO

-- 2.1 Dữ liệu Người dùng
INSERT INTO Users (FullName, Email, PhoneNumber, PasswordHash, UserType) VALUES
(N'Nguyễn Văn An', 'nguyenvanan@email.com', '0901234567', HASHBYTES('SHA2_256','hash_password_123'), 'Customer'),
(N'Trần Thị Bình', 'tranthib@email.com', '0902234567', HASHBYTES('SHA2_256','hash_password_456'), 'Customer'),
(N'Lê Văn Cường', 'levancuong@email.com', '0903234567', HASHBYTES('SHA2_256','hash_password_789'), 'Staff'),
(N'Phạm Thị Dung', 'phamthidung@email.com', '0904234567', HASHBYTES('SHA2_256','hash_password_abc'), 'Admin'),
(N'Hoàng Văn Em', 'hoangvanem@email.com', '0905234567', HASHBYTES('SHA2_256','hash_password_def'), 'Customer'),
(N'Đỗ Thị Phương', 'dothiphuong@email.com', '0906234567', HASHBYTES('SHA2_256','hash_password_ghi'), 'Customer');


-- 2.2 Dữ liệu Ga tàu
INSERT INTO Stations (StationCode, StationName, City, Province, Address) VALUES
('HN', N'Hà Nội', N'Hà Nội', N'Hà Nội', N'120 Lê Duẩn, Hoàn Kiếm'),
('HP', N'Hải Phòng', N'Hải Phòng', N'Hải Phòng', N'75 Lương Khánh Thiện'),
('VT', N'Vinh', N'Vinh', N'Nghệ An', N'Đường Lê Lợi'),
('HUE', N'Huế', N'Huế', N'Thừa Thiên Huế', N'2 Bùi Thị Xuân'),
('DN', N'Đà Nẵng', N'Đà Nẵng', N'Đà Nẵng', N'202 Hải Phòng'),
('QN', N'Quảng Ngãi', N'Quảng Ngãi', N'Quảng Ngãi', N'Đường Quang Trung'),
('NHA', N'Nha Trang', N'Nha Trang', N'Khánh Hòa', N'26 Thái Nguyên'),
('SG', N'Sài Gòn', N'TP. Hồ Chí Minh', N'TP. Hồ Chí Minh', N'1 Nguyễn Thông, Q.3');

-- 2.3 Dữ liệu Tuyến tàu
INSERT INTO Routes (RouteCode, DepartureStationID, ArrivalStationID, Distance, EstimatedDuration) VALUES
('HN-SG', 1, 8, 1726, 1920), -- 32 giờ
('HN-DN', 1, 5, 764, 780),   -- 13 giờ
('HN-HUE', 1, 4, 658, 660),  -- 11 giờ
('DN-SG', 5, 8, 964, 900),   -- 15 giờ
('HN-VT', 1, 3, 319, 360),   -- 6 giờ
('HUE-SG', 4, 8, 1068, 1080); -- 18 giờ

-- 2.4 Dữ liệu Hạng ghế
INSERT INTO SeatClasses (ClassName, Description, PriceMultiplier) VALUES
(N'Ghế cứng', N'Ghế ngồi cứng, phù hợp quãng đường ngắn', 1.0),
(N'Ghế mềm điều hòa', N'Ghế ngồi mềm có điều hòa', 1.3),
(N'Giường nằm khoang 6', N'Giường nằm 6 người/khoang', 1.5),
(N'Giường nằm khoang 4', N'Giường nằm 4 người/khoang, cao cấp', 2.0),
(N'Giường nằm VIP', N'Giường nằm 2 người/khoang, cao cấp nhất', 2.5);

-- 2.5 Dữ liệu Đoàn tàu
INSERT INTO Trains (TrainCode, TrainName, TrainType, TotalCoaches) VALUES
('SE1', N'Thống Nhất SE1', 'SE', 12),
('SE2', N'Thống Nhất SE2', 'SE', 12),
('SE3', N'Thống Nhất SE3', 'SE', 10),
('SE4', N'Thống Nhất SE4', 'SE', 10),
('TN1', N'Tàu Nhanh TN1', 'TN', 8),
('SNT1', N'Sài Gòn - Nha Trang', 'SNT', 6);

-- 2.6 Dữ liệu Toa tàu (Ví dụ cho tàu SE1)
INSERT INTO Coaches (TrainID, CoachNumber, SeatClassID, TotalSeats) VALUES
(1, 1, 1, 64),  -- Toa 1: Ghế cứng
(1, 2, 1, 64),  -- Toa 2: Ghế cứng
(1, 3, 2, 52),  -- Toa 3: Ghế mềm
(1, 4, 2, 52),  -- Toa 4: Ghế mềm
(1, 5, 3, 36),  -- Toa 5: Giường nằm khoang 6
(1, 6, 3, 36),  -- Toa 6: Giường nằm khoang 6
(1, 7, 4, 24),  -- Toa 7: Giường nằm khoang 4
(1, 8, 4, 24),  -- Toa 8: Giường nằm khoang 4
(1, 9, 5, 12),  -- Toa 9: VIP
(2, 1, 1, 64),  -- Tàu SE2
(2, 2, 2, 52),
(2, 3, 3, 36),
(2, 4, 4, 24);

-- 2.7 Dữ liệu Ghế ngồi (Ví dụ cho toa 1)
DECLARE @CoachID INT = 1;
DECLARE @SeatNum INT = 1;
WHILE @SeatNum <= 64
BEGIN
    INSERT INTO Seats (CoachID, SeatNumber, SeatType) 
    VALUES (@CoachID, RIGHT('00' + CAST(@SeatNum AS VARCHAR), 2), 'Single');
    SET @SeatNum = @SeatNum + 1;
END

-- Thêm ghế cho toa giường nằm (Toa 5)
SET @CoachID = 5;
SET @SeatNum = 1;
WHILE @SeatNum <= 36
BEGIN
    DECLARE @Type NVARCHAR(20) = CASE WHEN @SeatNum % 3 = 1 THEN 'Lower' 
                                      WHEN @SeatNum % 3 = 2 THEN 'Middle' 
                                      ELSE 'Upper' END;
    INSERT INTO Seats (CoachID, SeatNumber, SeatType) 
    VALUES (@CoachID, RIGHT('00' + CAST(@SeatNum AS VARCHAR), 2), @Type);
    SET @SeatNum = @SeatNum + 1;
END

-- 2.8 Dữ liệu Lịch trình
INSERT INTO Schedules (TrainID, RouteID, DepartureTime, ArrivalTime, BasePrice, AvailableSeats) VALUES
(1, 1, '2025-11-25 19:00', '2025-11-26 03:00', 800000, 350),
(2, 1, '2025-11-02 06:00', '2025-11-03 14:00', 800000, 350),
(3, 2, '2025-11-01 22:00', '2025-11-02 11:00', 450000, 280),
(4, 2, '2025-11-02 08:00', '2025-11-02 21:00', 450000, 280),
(5, 3, '2025-11-18 14:00', '2025-11-19 01:00', 350000, 220),
(1, 1, '2025-11-20 19:00', '2025-11-21 03:00', 850000, 350);

-- 2.9 Dữ liệu Đặt vé
--INSERT INTO Bookings (BookingCode, UserID, ScheduleID, TotalAmount, PaymentStatus, BookingStatus) VALUES
--('BK20251001001', 1, 1, 1200000, 'Paid', 'Active'),
--('BK20251001002', 2, 3, 585000, 'Paid', 'Active'),
--('BK20251001003', 5, 5, 350000, 'Pending', 'Active'),
--('BK20251002001', 6, 2, 1600000, 'Paid', 'Active');

-- 2.10 Dữ liệu Vé (Tickets)
--INSERT INTO Tickets (BookingID, SeatID, PassengerName, PassengerIDNumber, PassengerPhone, TicketPrice, TicketStatus) VALUES
--(1, 10, N'Nguyễn Văn An', '001234567890', '0901234567', 1200000, 'Valid'),
--(2, 20, N'Trần Thị Bình', '001234567891', '0902234567', 585000, 'Valid'),
--(3, 30, N'Hoàng Văn Em', '001234567892', '0905234567', 350000, 'Valid'),
--(4, 75, N'Đỗ Thị Phương', '001234567893', '0906234567', 800000, 'Valid'),
--(4, 76, N'Nguyễn Thị Lan', '001234567894', '0907234567', 800000, 'Valid');

-- 2.11 Dữ liệu Thanh toán
--INSERT INTO Payments (BookingID, PaymentMethod, TransactionID, Amount, PaymentStatus, ResponseCode) VALUES
--(1, 'Momo', 'MOMO_TXN_001', 1200000, 'Success', '00'),
--(2, 'ZaloPay', 'ZALO_TXN_001', 585000, 'Success', '00'),
--(4, 'Visa', 'VISA_TXN_001', 1600000, 'Success', '00');

-- 2.12 Dữ liệu Chính sách hoàn hủy
INSERT INTO RefundPolicies (HoursBeforeDeparture, RefundPercentage, Description) VALUES
(72, 90, N'Hoàn 90% nếu hủy trước 72 giờ'),
(48, 70, N'Hoàn 70% nếu hủy trước 48 giờ'),
(24, 50, N'Hoàn 50% nếu hủy trước 24 giờ'),
(12, 30, N'Hoàn 30% nếu hủy trước 12 giờ'),
(0, 0, N'Không hoàn nếu hủy trong vòng 12 giờ');

GO

-- 3.1 Thủ tục Thêm người dùng
CREATE OR ALTER PROCEDURE sp_SignUp
    @FullName NVARCHAR(100),
    @Email NVARCHAR(100),
    @PhoneNumber NVARCHAR(20),
    @Password VARCHAR(255),
    @UserType NVARCHAR(20) = 'Customer'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
		IF EXISTS (SELECT TOP 1 1 FROM Users WHERE Email = @Email OR PhoneNumber = @PhoneNumber)
		BEGIN
			PRINT 'Email or phone number have already existed!';
			RETURN -1;
		END
		IF LEN(@Password) < 8
		BEGIN
			PRINT 'Password length must be greater than 0';
			RETURN -1;
		END

        INSERT INTO Users (FullName, Email, PhoneNumber, PasswordHash, UserType)
        VALUES (@FullName, @Email, @PhoneNumber, HASHBYTES('SHA2_256',@Password), @UserType);
        
        SELECT SCOPE_IDENTITY() AS NewUserID, 'Success' AS Status;
    END TRY
    BEGIN CATCH
        SELECT 0 AS NewUserID, ERROR_MESSAGE() AS Status;
    END CATCH
END
GO

-- 3.2 Hàm kiểm tra đăng nhập hợp lệ
CREATE OR ALTER FUNCTION fn_IsValidLoginAttempt
(
    @Email NVARCHAR(100),
    @Password VARCHAR(255)
)
RETURNS BIT
AS
BEGIN
    DECLARE @Result BIT = 0;

    IF EXISTS (
        SELECT 1
        FROM Users AS u
        WHERE u.Email = @Email
          AND u.PasswordHash = HASHBYTES('SHA2_256', @Password)
    )
        SET @Result = 1;

    RETURN @Result;
END
GO

-- 3.2 Thủ tục Sửa thông tin người dùng
CREATE OR ALTER PROCEDURE sp_UpdateUser
    @UserID INT,
    @FullName NVARCHAR(100),
    @Email NVARCHAR(100),
    @PhoneNumber NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE Users
        SET FullName = @FullName,
            Email = @Email,
            PhoneNumber = @PhoneNumber
        WHERE UserID = @UserID;
        
        SELECT 'Success' AS Status, @@ROWCOUNT AS RowsAffected;
    END TRY
    BEGIN CATCH
        SELECT ERROR_MESSAGE() AS Status, 0 AS RowsAffected;
    END CATCH
END
GO

-- 3.3 Thủ tục Xóa người dùng (Soft delete)
CREATE OR ALTER PROCEDURE sp_DeleteUser
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE Users
        SET IsActive = 0
        WHERE UserID = @UserID;
        
        SELECT 'Success' AS Status;
    END TRY
    BEGIN CATCH
        SELECT ERROR_MESSAGE() AS Status;
    END CATCH
END
GO

-- 3.4 Thủ tục Thêm chuyến tàu
CREATE OR ALTER PROCEDURE sp_AddSchedule
    @TrainID INT,
    @RouteID INT,
    @DepartureTime DATETIME,
    @ArrivalTime DATETIME,
    @BasePrice DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Tính tổng ghế trống
        DECLARE @TotalSeats INT;
        SELECT @TotalSeats = SUM(c.TotalSeats)
        FROM Coaches c
        WHERE c.TrainID = @TrainID;
        
        INSERT INTO Schedules (TrainID, RouteID, DepartureTime, ArrivalTime, BasePrice, AvailableSeats)
        VALUES (@TrainID, @RouteID, @DepartureTime, @ArrivalTime, @BasePrice, @TotalSeats);
        
        SELECT SCOPE_IDENTITY() AS NewScheduleID, 'Success' AS Status;
    END TRY
    BEGIN CATCH
        SELECT 0 AS NewScheduleID, ERROR_MESSAGE() AS Status;
    END CATCH
END
GO

-- 3.5 Thủ tục Sửa lịch trình
CREATE OR ALTER PROCEDURE sp_UpdateSchedule
    @ScheduleID INT,
    @DepartureTime DATETIME,
    @ArrivalTime DATETIME,
    @BasePrice DECIMAL(10,2),
    @Status NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE Schedules
        SET DepartureTime = @DepartureTime,
            ArrivalTime = @ArrivalTime,
            BasePrice = @BasePrice,
            Status = @Status
        WHERE ScheduleID = @ScheduleID;
        
        SELECT 'Success' AS Status;
    END TRY
    BEGIN CATCH
        SELECT ERROR_MESSAGE() AS Status;
    END CATCH
END
GO

-- 3.6 Thủ tục Hủy chuyến tàu
CREATE OR ALTER PROCEDURE sp_CancelSchedule
    @ScheduleID INT,
    @Reason NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Cập nhật trạng thái chuyến
        UPDATE Schedules
        SET Status = 'Cancelled'
        WHERE ScheduleID = @ScheduleID;
        
        -- Hủy tất cả booking liên quan
        UPDATE Bookings
        SET BookingStatus = 'Cancelled',
            CancelledAt = GETDATE(),
            CancellationReason = @Reason
        WHERE ScheduleID = @ScheduleID AND BookingStatus = 'Active';
        
        -- Gửi thông báo
        INSERT INTO Notifications (UserID, BookingID, NotificationType, Title, Message)
        SELECT b.UserID, b.BookingID, 'Cancellation',
               N'Chuyến tàu bị hủy',
               N'Chuyến tàu ' + t.TrainCode + N' đã bị hủy. Lý do: ' + @Reason
        FROM Bookings b
        JOIN Schedules s ON b.ScheduleID = s.ScheduleID
        JOIN Trains t ON s.TrainID = t.TrainID
        WHERE s.ScheduleID = @ScheduleID;
        
        COMMIT TRANSACTION;
        SELECT 'Success' AS Status;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS Status;
    END CATCH
END
GO

-- 3.7 Thủ tục Thêm booking
CREATE OR ALTER PROCEDURE sp_CreateBooking
    @UserID INT,
    @ScheduleID INT,
    @SeatIDs NVARCHAR(100), -- ví dụ: '12,15' (2 ghế)
    @PassengerNames NVARCHAR(200), -- ví dụ: 'Nguyen Van A,Tran Thi B'
    @PaymentMethod NVARCHAR(50) = 'VNPay'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TranStarted BIT = 0;

    BEGIN TRY
        IF @@TRANCOUNT = 0
        BEGIN TRANSACTION;
        SET @TranStarted = 1;

        DECLARE @BasePrice DECIMAL(10,2),
                @TotalAmount DECIMAL(10,2) = 0,
                @BookingID INT,
                @BookingCode NVARCHAR(20),
                @SeatID INT,
                @PassengerName NVARCHAR(100),
                @SeatClassID INT,
                @PriceMultiplier DECIMAL(4,2),
                @TicketPrice DECIMAL(10,2),
                @i INT = 1;

        SELECT @BasePrice = BasePrice
        FROM Schedules
        WHERE ScheduleID = @ScheduleID
          AND Status = 'Scheduled';

        IF @BasePrice IS NULL
            THROW 50001, 'Lịch trình không tồn tại hoặc đã bị hủy.', 1;

        SET @BookingCode = 'BK' + FORMAT(GETDATE(), 'yyyyMMdd') + 
                          RIGHT('00000' + CAST(NEXT VALUE FOR BookingSeq AS VARCHAR), 5);

        INSERT INTO Bookings (BookingCode, UserID, ScheduleID, TotalAmount, PaymentStatus, BookingStatus)
        VALUES (@BookingCode, @UserID, @ScheduleID, 0, 'Pending', 'Active');

        SET @BookingID = SCOPE_IDENTITY();

        DECLARE @SeatList TABLE (SeatID INT, PassengerName NVARCHAR(100));
        DECLARE @SeatSplit TABLE (ID INT IDENTITY(1,1), SeatID INT);
        DECLARE @NameSplit TABLE (ID INT IDENTITY(1,1), PassengerName NVARCHAR(100));

        INSERT INTO @SeatSplit (SeatID)
        SELECT value FROM STRING_SPLIT(@SeatIDs, ',');

        INSERT INTO @NameSplit (PassengerName)
        SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@PassengerNames, ',');

        IF (SELECT COUNT(*) FROM @SeatSplit) != (SELECT COUNT(*) FROM @NameSplit)
            THROW 50002, 'Số lượng ghế và hành khách không khớp.', 1;

        WHILE @i <= (SELECT COUNT(*) FROM @SeatSplit)
        BEGIN
            SELECT @SeatID = SeatID FROM @SeatSplit WHERE ID = @i;
            SELECT @PassengerName = PassengerName FROM @NameSplit WHERE ID = @i;

            IF EXISTS (
                SELECT 1
                FROM Tickets t
                JOIN Bookings b ON t.BookingID = b.BookingID
                WHERE t.SeatID = @SeatID
                  AND b.ScheduleID = @ScheduleID
                  AND b.BookingStatus = 'Active'
                  AND t.TicketStatus = 'Valid'
            )
                THROW 50003, 'Một trong các ghế đã được đặt.', 1;

            SELECT @SeatClassID = c.SeatClassID
            FROM Seats s
            JOIN Coaches c ON s.CoachID = c.CoachID
            WHERE s.SeatID = @SeatID;

            SELECT @PriceMultiplier = PriceMultiplier
            FROM SeatClasses
            WHERE SeatClassID = @SeatClassID;

            IF @PriceMultiplier IS NULL SET @PriceMultiplier = 1.0;

            SET @TicketPrice = @BasePrice * @PriceMultiplier;
            SET @TotalAmount += @TicketPrice;

            -- Thêm Ticket
            INSERT INTO Tickets (BookingID, SeatID, PassengerName, TicketPrice, TicketStatus)
            VALUES (@BookingID, @SeatID, @PassengerName, @TicketPrice, 'Valid');

            SET @i += 1;
        END;

        UPDATE Bookings
        SET TotalAmount = @TotalAmount
        WHERE BookingID = @BookingID;

        UPDATE Schedules
        SET AvailableSeats = AvailableSeats - (SELECT COUNT(*) FROM @SeatSplit)
        WHERE ScheduleID = @ScheduleID;

        INSERT INTO Payments (BookingID, PaymentMethod, Amount, PaymentStatus)
        VALUES (@BookingID, @PaymentMethod, @TotalAmount, 'Pending');

        IF @TranStarted = 1 COMMIT TRANSACTION;

        SELECT 
            'Success' AS Result,
            @BookingCode AS BookingCode,
            @TotalAmount AS TotalAmount;
    END TRY
    BEGIN CATCH
        IF @TranStarted = 1 ROLLBACK TRANSACTION;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

        SELECT 
            'Error' AS Result,
            @ErrMsg AS Message
    END CATCH
END;
GO


-- Tạo sequence cho BookingCode
CREATE SEQUENCE BookingSeq START WITH 1 INCREMENT BY 1;
GO

-- 3.8 Thủ tục Hủy đặt vé
CREATE OR ALTER PROCEDURE sp_CancelBooking
    @BookingID INT,
    @CancellationReason NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE 
            @ScheduleID INT,
            @DepartureTime DATETIME,
            @HoursBeforeDeparture INT,
            @RefundPercentage DECIMAL(5,2),
            @SeatCount INT,
            @CurrentStatus NVARCHAR(20);

        SELECT 
            @ScheduleID = b.ScheduleID,
            @DepartureTime = s.DepartureTime,
            @CurrentStatus = b.BookingStatus
        FROM Bookings b
        JOIN Schedules s ON b.ScheduleID = s.ScheduleID
        WHERE b.BookingID = @BookingID;

        IF @ScheduleID IS NULL
            THROW 51001, 'Booking không tồn tại.', 1;

        IF @CurrentStatus <> 'Active'
            THROW 51002, 'Booking không ở trạng thái Active.', 1;

        SET @HoursBeforeDeparture = DATEDIFF(HOUR, GETDATE(), @DepartureTime);

        IF @HoursBeforeDeparture < 0
            THROW 51003, 'Chuyến tàu đã khởi hành, không thể hủy.', 1;

        SELECT TOP 1 @RefundPercentage = RefundPercentage
        FROM RefundPolicies
        WHERE HoursBeforeDeparture <= @HoursBeforeDeparture
        ORDER BY HoursBeforeDeparture DESC;

        IF @RefundPercentage IS NULL SET @RefundPercentage = 0;

        UPDATE Bookings
        SET 
            BookingStatus = 'Cancelled',
            CancelledAt = GETDATE(),
            CancellationReason = @CancellationReason,
            PaymentStatus = CASE WHEN @RefundPercentage > 0 THEN 'Refunded' ELSE PaymentStatus END
        WHERE BookingID = @BookingID AND BookingStatus = 'Active';

        UPDATE Tickets
        SET TicketStatus = 'Cancelled'
        WHERE BookingID = @BookingID AND TicketStatus = 'Valid';

        SELECT @SeatCount = COUNT(*) 
        FROM Tickets 
        WHERE BookingID = @BookingID AND TicketStatus = 'Cancelled';

        UPDATE Schedules
        SET AvailableSeats = AvailableSeats + @SeatCount
        WHERE ScheduleID = @ScheduleID;

        INSERT INTO Notifications (UserID, BookingID, NotificationType, Title, Message)
        SELECT 
            b.UserID,
            b.BookingID,
            'Cancellation',
            N'Booking Cancelled',
            N'Đặt vé #' + b.BookingCode + N' đã được hủy. Hoàn tiền: ' + CAST(@RefundPercentage AS NVARCHAR(10)) + N'%'
        FROM Bookings b WHERE b.BookingID = @BookingID;

        COMMIT TRANSACTION;

        SELECT 
            'Success' AS Status, 
            @RefundPercentage AS RefundPercentage,
            @SeatCount AS SeatsRestored;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT 
            'Error' AS Status, 
            ERROR_MESSAGE() AS Message, 
            ERROR_LINE() AS LineNumber;
    END CATCH
END
GO


-- 3.9 Thủ tục Thêm ga tàu
CREATE OR ALTER PROCEDURE sp_AddStation
    @StationCode NVARCHAR(10),
    @StationName NVARCHAR(100),
    @City NVARCHAR(50),
    @Province NVARCHAR(50),
    @Address NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO Stations (StationCode, StationName, City, Province, Address)
        VALUES (@StationCode, @StationName, @City, @Province, @Address);
        
        SELECT SCOPE_IDENTITY() AS NewStationID, 'Success' AS Status;
    END TRY
    BEGIN CATCH
        SELECT 0 AS NewStationID, ERROR_MESSAGE() AS Status;
    END CATCH
END
GO

-- 3.10 Thủ tục Sửa ga tàu
CREATE OR ALTER PROCEDURE sp_UpdateStation
    @StationID INT,
    @StationName NVARCHAR(100),
    @City NVARCHAR(50),
    @Province NVARCHAR(50),
    @Address NVARCHAR(200),
    @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE Stations
        SET StationName = @StationName,
            City = @City,
            Province = @Province,
            Address = @Address,
            IsActive = @IsActive
        WHERE StationID = @StationID;
        
        SELECT 'Success' AS Status;
    END TRY
    BEGIN CATCH
        SELECT ERROR_MESSAGE() AS Status;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_GetNotificationsByUser
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        n.NotificationID,
        n.NotificationType,
        n.Title,
        n.Message,
        n.IsRead,
        n.SentAt,
        n.ScheduledFor,
        b.BookingCode
    FROM Notifications n
    LEFT JOIN Bookings b ON n.BookingID = b.BookingID
    WHERE n.UserID = @UserID
    ORDER BY n.SentAt DESC;
END
GO

CREATE OR ALTER PROCEDURE sp_GetTicketsByUser
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        tk.TicketID,
        tk.PassengerName,
        tk.PassengerIDNumber,
        tk.PassengerPhone,
        tk.TicketPrice,
        tk.TicketStatus,
        b.BookingCode,
        s.DepartureTime,
        s.ArrivalTime,
        st1.StationName AS DepartureStation,
        st2.StationName AS ArrivalStation,
        t.TrainName,
        sc.ClassName AS SeatClass,
        c.CoachNumber,
        se.SeatNumber
    FROM Tickets tk
    JOIN Bookings b ON tk.BookingID = b.BookingID
    JOIN Schedules s ON b.ScheduleID = s.ScheduleID
    JOIN Routes r ON s.RouteID = r.RouteID
    JOIN Stations st1 ON r.DepartureStationID = st1.StationID
    JOIN Stations st2 ON r.ArrivalStationID = st2.StationID
    JOIN Trains t ON s.TrainID = t.TrainID
    JOIN Seats se ON tk.SeatID = se.SeatID
    JOIN Coaches c ON se.CoachID = c.CoachID
    JOIN SeatClasses sc ON c.SeatClassID = sc.SeatClassID
    WHERE b.UserID = @UserID
    ORDER BY s.DepartureTime DESC;
END
GO


CREATE OR ALTER PROCEDURE sp_GetPaymentHistoryByUser
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.PaymentID,
        b.BookingCode,
        p.PaymentMethod,
        p.TransactionID,
        p.Amount,
        p.PaymentStatus,
        p.ResponseCode,
        p.ResponseMessage,
        p.PaymentDate
    FROM Payments p
    JOIN Bookings b ON p.BookingID = b.BookingID
    WHERE b.UserID = @UserID
    ORDER BY p.PaymentDate DESC;
END
GO

-- =============================================
-- VIEW 
-- =============================================

-- 4.1 View: Danh sách chuyến tàu có sẵn
CREATE OR ALTER VIEW vw_AvailableSchedules AS
SELECT 
    s.ScheduleID,
    s.DepartureTime,
    s.ArrivalTime,
    t.TrainCode,
    t.TrainName,
    dep.StationName AS DepartureStation,
    arr.StationName AS ArrivalStation,
    r.Distance,
    r.EstimatedDuration,
    s.BasePrice,
    s.AvailableSeats,
    s.Status
FROM Schedules s
JOIN Trains t ON s.TrainID = t.TrainID
JOIN Routes r ON s.RouteID = r.RouteID
JOIN Stations dep ON r.DepartureStationID = dep.StationID
JOIN Stations arr ON r.ArrivalStationID = arr.StationID
WHERE s.Status = 'Scheduled' AND s.DepartureTime > GETDATE();
GO

-- 4.2 View: Chi tiết đặt vé của khách hàng
CREATE OR ALTER VIEW vw_CustomerBookings AS
SELECT 
    b.BookingID,
    b.BookingCode,
    b.BookingDate,
    u.FullName AS CustomerName,
    u.Email,
    u.PhoneNumber,
    s.DepartureTime,
    s.ArrivalTime,
    t.TrainCode,
    dep.StationName AS DepartureStation,
    arr.StationName AS ArrivalStation,
    b.TotalAmount,
    b.PaymentStatus,
    b.BookingStatus,
    COUNT(tk.TicketID) AS NumberOfTickets
FROM Bookings b
JOIN Users u ON b.UserID = u.UserID
JOIN Schedules s ON b.ScheduleID = s.ScheduleID
JOIN Trains t ON s.TrainID = t.TrainID
JOIN Routes r ON s.RouteID = r.RouteID
JOIN Stations dep ON r.DepartureStationID = dep.StationID
JOIN Stations arr ON r.ArrivalStationID = arr.StationID
LEFT JOIN Tickets tk ON b.BookingID = tk.BookingID
GROUP BY b.BookingID, b.BookingCode, b.BookingDate, u.FullName, u.Email, u.PhoneNumber,
         s.DepartureTime, s.ArrivalTime, t.TrainCode, dep.StationName, arr.StationName,
         b.TotalAmount, b.PaymentStatus, b.BookingStatus;
GO

-- 4.3 View: Chi tiết vé
CREATE OR ALTER VIEW vw_TicketDetails AS
SELECT 
    tk.TicketID,
    b.BookingCode,
    tk.PassengerName,
    tk.PassengerIDNumber,
    tk.PassengerPhone,
    t.TrainCode,
    dep.StationName AS DepartureStation,
    arr.StationName AS ArrivalStation,
    sch.DepartureTime,
    sch.ArrivalTime,
    c.CoachNumber,
    st.SeatNumber,
    sc.ClassName AS SeatClass,
    tk.TicketPrice,
    tk.TicketStatus
FROM Tickets tk
JOIN Bookings b ON tk.BookingID = b.BookingID
JOIN Schedules sch ON b.ScheduleID = sch.ScheduleID
JOIN Trains t ON sch.TrainID = t.TrainID
JOIN Routes r ON sch.RouteID = r.RouteID
JOIN Stations dep ON r.DepartureStationID = dep.StationID
JOIN Stations arr ON r.ArrivalStationID = arr.StationID
JOIN Seats st ON tk.SeatID = st.SeatID
JOIN Coaches c ON st.CoachID = c.CoachID
JOIN SeatClasses sc ON c.SeatClassID = sc.SeatClassID;
GO

-- 4.4 View: Sơ đồ chỗ ngồi theo chuyến
CREATE OR ALTER VIEW vw_SeatAvailability AS
SELECT 
    s.ScheduleID,
    t.TrainCode,
    c.CoachNumber,
    sc.ClassName,
    st.SeatID,
    st.SeatNumber,
    st.SeatType,
    CASE 
        WHEN tk.TicketID IS NOT NULL AND b.BookingStatus = 'Active' THEN 'Booked'
        ELSE 'Available'
    END AS SeatStatus
FROM Schedules s
JOIN Trains t ON s.TrainID = t.TrainID
JOIN Coaches c ON t.TrainID = c.TrainID
JOIN SeatClasses sc ON c.SeatClassID = sc.SeatClassID
JOIN Seats st ON c.CoachID = st.CoachID
LEFT JOIN Tickets tk ON st.SeatID = tk.SeatID
LEFT JOIN Bookings b ON tk.BookingID = b.BookingID AND b.ScheduleID = s.ScheduleID
WHERE s.Status = 'Scheduled';
GO

-- 4.5 View: Lịch sử thanh toán
CREATE OR ALTER VIEW vw_PaymentHistory AS
SELECT 
    p.PaymentID,
    p.TransactionID,
    b.BookingCode,
    u.FullName AS CustomerName,
    p.PaymentMethod,
    p.Amount,
    p.PaymentDate,
    p.PaymentStatus,
    t.TrainCode,
    dep.StationName AS DepartureStation,
    arr.StationName AS ArrivalStation
FROM Payments p
JOIN Bookings b ON p.BookingID = b.BookingID
JOIN Users u ON b.UserID = u.UserID
JOIN Schedules s ON b.ScheduleID = s.ScheduleID
JOIN Trains t ON s.TrainID = t.TrainID
JOIN Routes r ON s.RouteID = r.RouteID
JOIN Stations dep ON r.DepartureStationID = dep.StationID
JOIN Stations arr ON r.ArrivalStationID = arr.StationID;
GO

-- 4.6 View: Thông báo chưa đọc
CREATE OR ALTER VIEW vw_UnreadNotifications AS
SELECT 
    n.NotificationID,
    n.UserID,
    u.FullName,
    u.Email,
    n.NotificationType,
    n.Title,
    n.Message,
    n.SentAt,
    b.BookingCode
FROM Notifications n
JOIN Users u ON n.UserID = u.UserID
LEFT JOIN Bookings b ON n.BookingID = b.BookingID
WHERE n.IsRead = 0;
GO

-- =============================================
-- 5. SP và Function tính toán
-- =============================================

-- 5.1 Hàm tính giá vé theo hạng ghế
CREATE OR ALTER FUNCTION fn_CalculateTicketPrice
(
    @ScheduleID INT,
    @SeatClassID INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Price DECIMAL(10,2);
    
    SELECT @Price = s.BasePrice * sc.PriceMultiplier
    FROM Schedules s, SeatClasses sc
    WHERE s.ScheduleID = @ScheduleID AND sc.SeatClassID = @SeatClassID;
    
    RETURN ISNULL(@Price, 0);
END
GO

-- 5.2 Hàm tính phần trăm hoàn tiền
CREATE OR ALTER FUNCTION fn_GetRefundPercentage
(
    @BookingID INT
)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @RefundPercentage DECIMAL(5,2);
    DECLARE @DepartureTime DATETIME;
    
    SELECT @DepartureTime = s.DepartureTime
    FROM Bookings b
    JOIN Schedules s ON b.ScheduleID = s.ScheduleID
    WHERE b.BookingID = @BookingID;
    
    DECLARE @HoursBeforeDeparture INT;
    SET @HoursBeforeDeparture = DATEDIFF(HOUR, GETDATE(), @DepartureTime);
    
    SELECT TOP 1 @RefundPercentage = RefundPercentage
    FROM RefundPolicies
    WHERE HoursBeforeDeparture <= @HoursBeforeDeparture
    ORDER BY HoursBeforeDeparture DESC;
    
    RETURN ISNULL(@RefundPercentage, 0);
END
GO

-- 5.3 Thủ tục tìm kiếm chuyến tàu
CREATE OR ALTER PROCEDURE sp_SearchTrains
    @DepartureStationID INT,
    @ArrivalStationID INT,
    @DepartureDate DATE,
    @SeatClassID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        s.ScheduleID,
        t.TrainCode,
        t.TrainName,
        dep.StationName AS DepartureStation,
        arr.StationName AS ArrivalStation,
        s.DepartureTime,
        s.ArrivalTime,
        DATEDIFF(MINUTE, s.DepartureTime, s.ArrivalTime) AS TravelTimeMinutes,
        CASE 
            WHEN @SeatClassID IS NOT NULL 
            THEN dbo.fn_CalculateTicketPrice(s.ScheduleID, @SeatClassID)
            ELSE s.BasePrice
        END AS Price,
        s.AvailableSeats,
        sc.ClassName AS SeatClass
    FROM Schedules s
    JOIN Trains t ON s.TrainID = t.TrainID
    JOIN Routes r ON s.RouteID = r.RouteID
    JOIN Stations dep ON r.DepartureStationID = dep.StationID
    JOIN Stations arr ON r.ArrivalStationID = arr.StationID
    LEFT JOIN Coaches c ON t.TrainID = c.TrainID AND (@SeatClassID IS NULL OR c.SeatClassID = @SeatClassID)
    LEFT JOIN SeatClasses sc ON c.SeatClassID = sc.SeatClassID
    WHERE r.DepartureStationID = @DepartureStationID
        AND r.ArrivalStationID = @ArrivalStationID
        AND CAST(s.DepartureTime AS DATE) = @DepartureDate
        AND s.Status = 'Scheduled'
        AND s.AvailableSeats > 0
    ORDER BY s.DepartureTime;
END
GO

-- 5.4 Thủ tục kiểm tra ghế trống
CREATE OR ALTER PROCEDURE sp_CheckSeatAvailability
    @ScheduleID INT,
    @CoachID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        st.SeatID,
        st.SeatNumber,
        st.SeatType,
        sc.ClassName,
        CASE 
            WHEN tk.TicketID IS NOT NULL AND b.BookingStatus = 'Active' THEN 0
            ELSE 1
        END AS IsAvailable,
        dbo.fn_CalculateTicketPrice(@ScheduleID, c.SeatClassID) AS Price
    FROM Seats st
    JOIN Coaches c ON st.CoachID = c.CoachID
    JOIN SeatClasses sc ON c.SeatClassID = sc.SeatClassID
    LEFT JOIN Tickets tk ON st.SeatID = tk.SeatID
    LEFT JOIN Bookings b ON tk.BookingID = b.BookingID AND b.ScheduleID = @ScheduleID
    WHERE c.CoachID = @CoachID
    ORDER BY st.SeatNumber;
END
GO

-- 5.5 Thủ tục xử lý thanh toán
CREATE OR ALTER PROCEDURE sp_ProcessPayment
    @BookingID INT,
    @TransactionID NVARCHAR(100),
    @ResponseCode NVARCHAR(10) = '00'
AS
BEGIN
    SET NOCOUNT ON;
	DECLARE @TranStarted INT = 0;
    BEGIN TRY
        BEGIN TRANSACTION;
		SET @TranStarted = 1;
        DECLARE @CurrentStatus NVARCHAR(20);
        DECLARE @ExistingPaymentID INT;
		DECLARE @Amount INT;

        SELECT @CurrentStatus = BookingStatus
        FROM Bookings
        WHERE BookingID = @BookingID;

        IF @CurrentStatus IS NULL
            THROW 54001, 'Booking không tồn tại.', 1;

        IF @CurrentStatus <> 'Active'
            THROW 54002, 'Booking không ở trạng thái Active, không thể thanh toán.', 1;

        SELECT TOP 1 @ExistingPaymentID = PaymentID
        FROM Payments
        WHERE BookingID = @BookingID
        ORDER BY PaymentID DESC;

		SELECT TOP 1 @Amount = TotalAmount
		FROM Bookings
		WHERE BookingID = @BookingID;

        IF @ExistingPaymentID IS NOT NULL
        BEGIN
            UPDATE Payments
            SET TransactionID = @TransactionID,
                Amount = @Amount,
                PaymentStatus = CASE WHEN @ResponseCode = '00' THEN 'Success' ELSE 'Failed' END,
                ResponseCode = @ResponseCode,
                ResponseMessage = CASE WHEN @ResponseCode = '00' THEN 'Payment successful' ELSE 'Payment failed' END,
                PaymentDate = CASE WHEN @ResponseCode = '00' THEN GETDATE() ELSE NULL END
            WHERE PaymentID = @ExistingPaymentID;
        END
		ELSE THROW 54003, 'Không tồn tại payment, kiểm tra lại thông tin booking!', 1;

        IF @ResponseCode = '00'
        BEGIN
            UPDATE Bookings
            SET PaymentStatus = 'Paid'
            WHERE BookingID = @BookingID;

            UPDATE Tickets
            SET TicketStatus = 'Valid'
            WHERE BookingID = @BookingID;
        END

        COMMIT TRANSACTION;
        SELECT 'Success' AS Status, @ExistingPaymentID AS PaymentID;
    END TRY
    BEGIN CATCH
		IF @TranStarted = 1 ROLLBACK TRANSACTION;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

        -- Ghi log lỗi payment
        INSERT INTO Payments (BookingID, TransactionID, Amount, PaymentStatus, ResponseCode, ResponseMessage)
        VALUES (@BookingID, @TransactionID, @Amount, 'Failed', '99', @ErrMsg);

        SELECT @ErrMsg AS Status;
    END CATCH
END
GO


-- 5.6 Thủ tục gửi nhắc nhở
CREATE OR ALTER PROCEDURE sp_SendDepartureReminders
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Gửi nhắc nhở cho các chuyến sắp khởi hành trong 24 giờ
    INSERT INTO Notifications (UserID, BookingID, NotificationType, Title, Message, ScheduledFor)
    SELECT 
        b.UserID,
        b.BookingID,
        'Reminder',
        N'Nhắc nhở chuyến đi',
        N'Chuyến tàu ' + t.TrainCode + N' của bạn sẽ khởi hành lúc ' + 
        FORMAT(s.DepartureTime, 'HH:mm dd/MM/yyyy') + N'. Vui lòng có mặt trước 30 phút.',
        DATEADD(HOUR, -2, s.DepartureTime)
    FROM Bookings b
    JOIN Schedules s ON b.ScheduleID = s.ScheduleID
    JOIN Trains t ON s.TrainID = t.TrainID
    WHERE b.BookingStatus = 'Active'
        AND b.PaymentStatus = 'Paid'
        AND DATEDIFF(HOUR, GETDATE(), s.DepartureTime) BETWEEN 2 AND 24
        AND NOT EXISTS (
            SELECT 1 FROM Notifications n 
            WHERE n.BookingID = b.BookingID AND n.NotificationType = 'Reminder'
        );
    
    SELECT @@ROWCOUNT AS NotificationsSent;
END
GO

-- =============================================
-- 6. THỦ TỤC THỐNG KÊ
-- =============================================

-- 6.1 Thống kê doanh thu theo ngày
CREATE OR ALTER PROCEDURE sp_RevenueByDate
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        CAST(b.BookingDate AS DATE) AS BookingDate,
        COUNT(DISTINCT b.BookingID) AS TotalBookings,
        COUNT(tk.TicketID) AS TotalTickets,
        SUM(b.TotalAmount) AS TotalRevenue,
        SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS PaidRevenue,
        SUM(CASE WHEN b.BookingStatus = 'Cancelled' THEN b.TotalAmount ELSE 0 END) AS CancelledRevenue
    FROM Bookings b
    LEFT JOIN Tickets tk ON b.BookingID = tk.BookingID
    WHERE CAST(b.BookingDate AS DATE) BETWEEN @StartDate AND @EndDate
    GROUP BY CAST(b.BookingDate AS DATE)
    ORDER BY BookingDate DESC;
END
GO

-- 6.2 Thống kê theo tuyến đường
CREATE OR ALTER PROCEDURE sp_RevenueByRoute
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        r.RouteCode,
        dep.StationName AS DepartureStation,
        arr.StationName AS ArrivalStation,
        COUNT(DISTINCT b.BookingID) AS TotalBookings,
        COUNT(tk.TicketID) AS TotalTickets,
        SUM(b.TotalAmount) AS TotalRevenue,
        AVG(b.TotalAmount) AS AverageBookingValue
    FROM Bookings b
    JOIN Schedules s ON b.ScheduleID = s.ScheduleID
    JOIN Routes r ON s.RouteID = r.RouteID
    JOIN Stations dep ON r.DepartureStationID = dep.StationID
    JOIN Stations arr ON r.ArrivalStationID = arr.StationID
    LEFT JOIN Tickets tk ON b.BookingID = tk.BookingID
    WHERE CAST(b.BookingDate AS DATE) BETWEEN @StartDate AND @EndDate
        AND b.PaymentStatus = 'Paid'
    GROUP BY r.RouteCode, dep.StationName, arr.StationName
    ORDER BY TotalRevenue DESC;
END
GO

-- 6.3 Thống kê theo hạng ghế
CREATE OR ALTER PROCEDURE sp_RevenueBySeatClass
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        sc.ClassName,
        COUNT(tk.TicketID) AS TicketsSold,
        SUM(tk.TicketPrice) AS TotalRevenue,
        AVG(tk.TicketPrice) AS AveragePrice,
        CAST(COUNT(tk.TicketID) * 100.0 / SUM(COUNT(tk.TicketID)) OVER() AS DECIMAL(5,2)) AS PercentageOfTotal
    FROM Tickets tk
    JOIN Bookings b ON tk.BookingID = b.BookingID
    JOIN Seats st ON tk.SeatID = st.SeatID
    JOIN Coaches c ON st.CoachID = c.CoachID
    JOIN SeatClasses sc ON c.SeatClassID = sc.SeatClassID
    WHERE CAST(b.BookingDate AS DATE) BETWEEN @StartDate AND @EndDate
        AND b.PaymentStatus = 'Paid'
    GROUP BY sc.ClassName
    ORDER BY TotalRevenue DESC;
END
GO

-- 6.5 Thống kê khách hàng
CREATE OR ALTER PROCEDURE sp_CustomerStatistics
    @TopN INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@TopN)
        u.UserID,
        u.FullName,
        u.Email,
        u.PhoneNumber,
        COUNT(DISTINCT b.BookingID) AS TotalBookings,
        COUNT(tk.TicketID) AS TotalTickets,
        SUM(b.TotalAmount) AS TotalSpent,
        MAX(b.BookingDate) AS LastBookingDate,
        DATEDIFF(DAY, u.CreatedAt, GETDATE()) AS DaysSinceRegistration
    FROM Users u
    LEFT JOIN Bookings b ON u.UserID = b.UserID AND b.PaymentStatus = 'Paid'
    LEFT JOIN Tickets tk ON b.BookingID = tk.BookingID
    WHERE u.UserType = 'Customer'
    GROUP BY u.UserID, u.FullName, u.Email, u.PhoneNumber, u.CreatedAt
    ORDER BY TotalSpent DESC;
END
GO

-- 6.6 Thống kê phương thức thanh toán
CREATE OR ALTER PROCEDURE sp_PaymentMethodStatistics
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        p.PaymentMethod,
        COUNT(p.PaymentID) AS TransactionCount,
        SUM(p.Amount) AS TotalAmount,
        AVG(p.Amount) AS AverageAmount,
        SUM(CASE WHEN p.PaymentStatus = 'Success' THEN 1 ELSE 0 END) AS SuccessCount,
        SUM(CASE WHEN p.PaymentStatus = 'Failed' THEN 1 ELSE 0 END) AS FailedCount,
        CAST(SUM(CASE WHEN p.PaymentStatus = 'Success' THEN 1 ELSE 0 END) * 100.0 / COUNT(p.PaymentID) AS DECIMAL(5,2)) AS SuccessRate
    FROM Payments p
    WHERE CAST(p.PaymentDate AS DATE) BETWEEN @StartDate AND @EndDate
    GROUP BY p.PaymentMethod
    ORDER BY TotalAmount DESC;
END
GO

-- 7.3 Trigger: Ngăn xóa chuyến tàu có booking
CREATE OR ALTER TRIGGER trg_PreventScheduleDelete
ON Schedules
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM deleted d
        JOIN Bookings b ON d.ScheduleID = b.ScheduleID
        WHERE b.BookingStatus = 'Active'
    )
    BEGIN
        RAISERROR (N'Không thể xóa chuyến tàu đã có đặt vé', 16, 1);
        ROLLBACK TRANSACTION;
    END
    ELSE
    BEGIN
        DELETE FROM Schedules
        WHERE ScheduleID IN (SELECT ScheduleID FROM deleted);
    END
END
GO

---- 7.5 Trigger: Kiểm tra ghế trùng khi đặt vé
--CREATE OR ALTER TRIGGER trg_CheckDuplicateSeat
--ON Tickets
--INSTEAD OF INSERT
--AS
--BEGIN
--    -- Kiểm tra ghế đã được đặt chưa
--    IF EXISTS (
--        SELECT 1
--        FROM inserted i
--        JOIN Bookings b ON i.BookingID = b.BookingID
--        JOIN Tickets tk ON i.SeatID = tk.SeatID
--        JOIN Bookings b2 ON tk.BookingID = b2.BookingID
--        WHERE b.ScheduleID = b2.ScheduleID
--            AND b2.BookingStatus = 'Active'
--            AND tk.TicketStatus = 'Valid'
--    )
--    BEGIN
--        RAISERROR (N'Ghế đã được đặt cho chuyến này', 16, 1);
--        ROLLBACK TRANSACTION;
--    END
--    ELSE
--    BEGIN
--        INSERT INTO Tickets (BookingID, SeatID, PassengerName, PassengerIDNumber, PassengerPhone, TicketPrice, TicketStatus)
--        SELECT BookingID, SeatID, PassengerName, PassengerIDNumber, PassengerPhone, TicketPrice, TicketStatus
--        FROM inserted;
--    END
--END
--GO

---- 7.6 Trigger: Cập nhật trạng thái vé khi booking bị hủy
--CREATE OR ALTER TRIGGER trg_CancelTicketsOnBookingCancel
--ON Bookings
--AFTER UPDATE
--AS
--BEGIN
--    IF UPDATE(BookingStatus)
--    BEGIN
--        UPDATE Tickets
--        SET TicketStatus = 'Cancelled'
--        FROM Tickets tk
--        INNER JOIN inserted i ON tk.BookingID = i.BookingID
--        WHERE i.BookingStatus = 'Cancelled' AND tk.TicketStatus != 'Cancelled';
--    END
--END
--GO

---- 7.8 Trigger: Kiểm tra thời gian đặt vé
--CREATE OR ALTER TRIGGER trg_CheckBookingTime
--ON Bookings
--INSTEAD OF INSERT
--AS
--BEGIN
--    -- Không cho đặt vé cho chuyến đã khởi hành hoặc sắp khởi hành trong 2 giờ
--    IF EXISTS (
--        SELECT 1
--        FROM inserted i
--        JOIN Schedules s ON i.ScheduleID = s.ScheduleID
--        WHERE DATEDIFF(HOUR, GETDATE(), s.DepartureTime) < 2
--    )
--    BEGIN
--        RAISERROR (N'Không thể đặt vé cho chuyến tàu khởi hành trong vòng 2 giờ', 16, 1);
--        ROLLBACK TRANSACTION;
--    END
--    ELSE
--    BEGIN
--        INSERT INTO Bookings (BookingCode, UserID, ScheduleID, BookingDate, TotalAmount, PaymentStatus, BookingStatus)
--        SELECT BookingCode, UserID, ScheduleID, BookingDate, TotalAmount, PaymentStatus, BookingStatus
--        FROM inserted;
--    END
--END
--GO

-- 7.10 Trigger: Gửi thông báo khi thanh toán thành công
CREATE OR ALTER TRIGGER trg_NotifyPaymentSuccess
ON Payments
AFTER UPDATE
AS
BEGIN
    IF EXISTS (SELECT * FROM inserted WHERE PaymentStatus = 'Success')
    BEGIN
        INSERT INTO Notifications (UserID, BookingID, NotificationType, Title, Message)
        SELECT 
            b.UserID,
            b.BookingID,
            'Payment',
            N'Thanh toán thành công',
            N'Bạn đã thanh toán thành công ' + FORMAT(i.Amount, 'N0') + N'đ cho mã đặt vé ' + b.BookingCode
        FROM inserted i
        JOIN Bookings b ON i.BookingID = b.BookingID
        WHERE i.PaymentStatus = 'Success';
    END
	ELSE
	BEGIN
		INSERT INTO Notifications (UserID, BookingID, NotificationType, Title, Message)
        SELECT 
            b.UserID,
            b.BookingID,
            'Payment',
            N'Thanh toán thất bại',
            N'Bạn đã thanh toán thất bại ' + FORMAT(i.Amount, 'N0') + N'đ cho mã đặt vé ' + b.BookingCode
        FROM inserted i
        JOIN Bookings b ON i.BookingID = b.BookingID
        WHERE i.PaymentStatus = 'Failed';
	END
END
GO

-- 9.1 Thủ tục xem lịch sử booking của user
CREATE OR ALTER PROCEDURE sp_GetCustomerBookingHistory
    @UserID INT,
    @Status NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        b.BookingID,
        b.BookingCode,
        b.BookingDate,
        t.TrainCode,
        t.TrainName,
        dep.StationName AS DepartureStation,
        arr.StationName AS ArrivalStation,
        s.DepartureTime,
        s.ArrivalTime,
        b.TotalAmount,
        b.PaymentStatus,
        b.BookingStatus,
        COUNT(tk.TicketID) AS NumberOfTickets
    FROM Bookings b
    JOIN Schedules s ON b.ScheduleID = s.ScheduleID
    JOIN Trains t ON s.TrainID = t.TrainID
    JOIN Routes r ON s.RouteID = r.RouteID
    JOIN Stations dep ON r.DepartureStationID = dep.StationID
    JOIN Stations arr ON r.ArrivalStationID = arr.StationID
    LEFT JOIN Tickets tk ON b.BookingID = tk.BookingID
    WHERE b.UserID = @UserID
        AND (@Status IS NULL OR b.BookingStatus = @Status)
    GROUP BY b.BookingID, b.BookingCode, b.BookingDate, t.TrainCode, t.TrainName,
             dep.StationName, arr.StationName, s.DepartureTime, s.ArrivalTime,
             b.TotalAmount, b.PaymentStatus, b.BookingStatus
    ORDER BY b.BookingDate DESC;
END
GO

-- 9.2 Thủ tục lấy chi tiết booking
CREATE OR ALTER PROCEDURE sp_GetBookingDetails
    @BookingID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        b.BookingID,
        b.BookingCode,
        b.BookingDate,
        b.TotalAmount,
        b.PaymentStatus,
        b.BookingStatus,
        u.FullName AS CustomerName,
        u.Email,
        u.PhoneNumber,
        t.TrainCode,
        t.TrainName,
        dep.StationName AS DepartureStation,
        dep.StationCode AS DepartureStationCode,
        arr.StationName AS ArrivalStation,
        arr.StationCode AS ArrivalStationCode,
        s.DepartureTime,
        s.ArrivalTime,
        r.Distance,
        r.EstimatedDuration,
        dbo.fn_GetRefundPercentage(@BookingID) AS RefundPercentage
    FROM Bookings b
    JOIN Users u ON b.UserID = u.UserID
    JOIN Schedules s ON b.ScheduleID = s.ScheduleID
    JOIN Trains t ON s.TrainID = t.TrainID
    JOIN Routes r ON s.RouteID = r.RouteID
    JOIN Stations dep ON r.DepartureStationID = dep.StationID
    JOIN Stations arr ON r.ArrivalStationID = arr.StationID
    WHERE b.BookingID = @BookingID;

    SELECT 
        tk.TicketID,
        tk.PassengerName,
        tk.PassengerIDNumber,
        tk.PassengerPhone,
        c.CoachNumber,
        st.SeatNumber,
        st.SeatType,
        sc.ClassName AS SeatClass,
        tk.TicketPrice,
        tk.TicketStatus
    FROM Tickets tk
    JOIN Seats st ON tk.SeatID = st.SeatID
    JOIN Coaches c ON st.CoachID = c.CoachID
    JOIN SeatClasses sc ON c.SeatClassID = sc.SeatClassID
    WHERE tk.BookingID = @BookingID;

    SELECT 
        p.PaymentID,
        p.PaymentMethod,
        p.TransactionID,
        p.Amount,
        p.PaymentDate,
        p.PaymentStatus
    FROM Payments p
    WHERE p.BookingID = @BookingID;
END
GO

-- 9.4 Thủ tục xuất báo cáo doanh thu tổng hợp
CREATE OR ALTER PROCEDURE sp_ComprehensiveRevenueReport
    @Year INT,
    @Month INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartDate DATE, @EndDate DATE;
    
    IF @Month IS NULL
    BEGIN
        SET @StartDate = DATEFROMPARTS(@Year, 1, 1);
        SET @EndDate = DATEFROMPARTS(@Year, 12, 31);
    END
    ELSE
    BEGIN
        SET @StartDate = DATEFROMPARTS(@Year, @Month, 1);
        SET @EndDate = EOMONTH(@StartDate);
    END

    SELECT 
        COUNT(DISTINCT b.BookingID) AS TotalBookings,
        COUNT(tk.TicketID) AS TotalTickets,
        SUM(b.TotalAmount) AS TotalRevenue,
        SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS PaidRevenue,
        SUM(CASE WHEN b.BookingStatus = 'Cancelled' THEN b.TotalAmount ELSE 0 END) AS CancelledAmount,
        AVG(b.TotalAmount) AS AverageBookingValue,
        COUNT(DISTINCT b.UserID) AS UniqueCustomers
    FROM Bookings b
    LEFT JOIN Tickets tk ON b.BookingID = tk.BookingID
    WHERE CAST(b.BookingDate AS DATE) BETWEEN @StartDate AND @EndDate;
    
    -- Theo tuyến
    SELECT 
        r.RouteCode,
        dep.StationName AS DepartureStation,
        arr.StationName AS ArrivalStation,
        COUNT(DISTINCT b.BookingID) AS Bookings,
        SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS Revenue
    FROM Bookings b
    JOIN Schedules s ON b.ScheduleID = s.ScheduleID
    JOIN Routes r ON s.RouteID = r.RouteID
    JOIN Stations dep ON r.DepartureStationID = dep.StationID
    JOIN Stations arr ON r.ArrivalStationID = arr.StationID
    WHERE CAST(b.BookingDate AS DATE) BETWEEN @StartDate AND @EndDate
    GROUP BY r.RouteCode, dep.StationName, arr.StationName
    ORDER BY Revenue DESC;
    
    -- Theo phương thức thanh toán
    SELECT 
        p.PaymentMethod,
        COUNT(p.PaymentID) AS Transactions,
        SUM(p.Amount) AS Amount
    FROM Payments p
    WHERE CAST(p.PaymentDate AS DATE) BETWEEN @StartDate AND @EndDate
        AND p.PaymentStatus = 'Success'
    GROUP BY p.PaymentMethod;
END
GO

-- 9.5 Thủ tục kiểm tra và cập nhật trạng thái chuyến tàu
CREATE OR ALTER PROCEDURE sp_UpdateScheduleStatus
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Cập nhật chuyến đã hoàn thành
    UPDATE Schedules
    SET Status = 'Completed'
    WHERE Status = 'Scheduled'
        AND ArrivalTime < GETDATE();
    
    -- Cập nhật trạng thái booking đã hoàn thành
    UPDATE Bookings
    SET BookingStatus = 'Completed'
    WHERE BookingStatus = 'Active'
        AND ScheduleID IN (
            SELECT ScheduleID FROM Schedules WHERE Status = 'Completed'
        );
    
    -- Cập nhật trạng thái vé đã sử dụng
    UPDATE Tickets
    SET TicketStatus = 'Used'
    WHERE TicketStatus = 'Valid'
        AND BookingID IN (
            SELECT BookingID FROM Bookings WHERE BookingStatus = 'Completed'
        );
    
    SELECT @@ROWCOUNT AS UpdatedRows;
END
GO

-- Thêm ghế cho các toa còn lại
DECLARE @CoachIDLoop INT;
DECLARE @TotalSeatsLoop INT;
DECLARE @SeatNumLoop INT;

DECLARE coach_cursor CURSOR FOR
SELECT CoachID, TotalSeats FROM Coaches WHERE CoachID > 5;

OPEN coach_cursor;
FETCH NEXT FROM coach_cursor INTO @CoachIDLoop, @TotalSeatsLoop;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SeatNumLoop = 1;
    WHILE @SeatNumLoop <= @TotalSeatsLoop
    BEGIN
        DECLARE @SeatTypeLoop NVARCHAR(20);
        IF @TotalSeatsLoop > 50
            SET @SeatTypeLoop = 'Single';
        ELSE
            SET @SeatTypeLoop = CASE WHEN @SeatNumLoop % 3 = 1 THEN 'Lower' 
                                     WHEN @SeatNumLoop % 3 = 2 THEN 'Middle' 
                                     ELSE 'Upper' END;
        
        INSERT INTO Seats (CoachID, SeatNumber, SeatType) 
        VALUES (@CoachIDLoop, RIGHT('00' + CAST(@SeatNumLoop AS VARCHAR), 2), @SeatTypeLoop);
        
        SET @SeatNumLoop = @SeatNumLoop + 1;
    END
    
    FETCH NEXT FROM coach_cursor INTO @CoachIDLoop, @TotalSeatsLoop;
END

CLOSE coach_cursor;
DEALLOCATE coach_cursor;

GO

-- Tính thời gian di chuyển
CREATE OR ALTER FUNCTION fn_CalculateTravelTime
(
    @DepartureTime DATETIME,
    @ArrivalTime DATETIME
)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @Hours INT = DATEDIFF(HOUR, @DepartureTime, @ArrivalTime);
    DECLARE @Minutes INT = DATEDIFF(MINUTE, @DepartureTime, @ArrivalTime) % 60;
    
    RETURN CAST(@Hours AS NVARCHAR(10)) + N' giờ ' + CAST(@Minutes AS NVARCHAR(10)) + N' phút';
END
GO

-- Kiểm tra ghế có sẵn không
CREATE OR ALTER FUNCTION fn_IsSeatAvailable
(
    @SeatID INT,
    @ScheduleID INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @IsAvailable BIT = 1;
    
    IF EXISTS (
        SELECT 1
        FROM Tickets tk
        JOIN Bookings b ON tk.BookingID = b.BookingID
        WHERE tk.SeatID = @SeatID
            AND b.ScheduleID = @ScheduleID
            AND b.BookingStatus = 'Active'
            AND tk.TicketStatus = 'Valid'
    )
    BEGIN
        SET @IsAvailable = 0;
    END
    
    RETURN @IsAvailable;
END
GO

-- Lấy tên đầy đủ tuyến đường
CREATE OR ALTER FUNCTION fn_GetRouteName
(
    @RouteID INT
)
RETURNS NVARCHAR(200)
AS
BEGIN
    DECLARE @RouteName NVARCHAR(200);
    
    SELECT @RouteName = dep.StationName + N' → ' + arr.StationName
    FROM Routes r
    JOIN Stations dep ON r.DepartureStationID = dep.StationID
    JOIN Stations arr ON r.ArrivalStationID = arr.StationID
    WHERE r.RouteID = @RouteID;
    
    RETURN @RouteName;
END
GO

-- =============================================
-- User flow 1
-- =============================================
DBCC FREEPROCCACHE;

--DECLARE @sql NVARCHAR(MAX) = N'';

--SELECT @sql = @sql + 'SELECT * FROM [' + s.name + '].[' + t.name + '];' + CHAR(13)
--FROM sys.tables t
--JOIN sys.schemas s ON t.schema_id = s.schema_id;

--PRINT @sql;
--EXEC sp_executesql @sql;

--GO

PRINT '=== User Flow ==='
SELECT * FROM Users;

EXEC sp_SignUp 'Trần Tôn Anh', 'tonanh@gmail.com', '0123456789', 'tonanh_hash_pass';
PRINT '=== 1. Login ===';
DECLARE @LoginAttemptResult BIT;
SET @LoginAttemptResult = dbo.fn_IsValidLoginAttempt('nguyenvanan@email.com','hash_password_123');

IF @LoginAttemptResult = 0 
    PRINT 'Your email and password are incorrect!';
ELSE 
    PRINT 'Login successfully!';

PRINT '=== 2. View list of trains ===';
SELECT * FROM Schedules;
SELECT * FROM vw_AvailableSchedules;

EXEC sp_SearchTrains 1, 8, '2025-11-25';

PRINT '=== 3. View seat availability ===';
EXEC sp_CheckSeatAvailability @ScheduleID = 1, @CoachID = 5;

PRINT '=== 4. Book Tickets ==='
EXEC sp_CreateBooking 1, 1, '3,4', 'Tôn, Anh';
EXEC sp_CreateBooking 2, 1, '12,13', 'Thanh, Hưng';
EXEC sp_CreateBooking 3, 1, '21,22,25', 'Long, VIệt, Bình';

SELECT * FROM vw_CustomerBookings;
EXEC sp_GetCustomerBookingHistory @UserID = 1;
EXEC sp_GetBookingDetails 1;

PRINT '=== 5. Pay ==='
EXEC sp_ProcessPayment 1, 'VNPay_TXN_001', '00';
SELECT * FROM vw_CustomerBookings;
EXEC sp_CheckSeatAvailability @ScheduleID = 1, @CoachID = 1;
EXEC sp_GetPaymentHistoryByUser 1;
EXEC sp_GetTicketsByUser 1;

PRINT '=== 6. Notifications ==='
SELECT * FROM Notifications;
EXEC sp_GetNotificationsByUser 1;

PRINT '=== 7. Payment History ==='
SELECT * FROM vw_PaymentHistory;

PRINT '=== 8. Cancel Booking ==='
EXEC sp_CancelBooking 1, 'busy';
EXEC sp_CheckSeatAvailability @ScheduleID = 1, @CoachID = 1;
SELECT * FROM Bookings;
SELECT * FROM Tickets;
SELECT * FROM RefundPolicies;