
USE TrainTicketSystem;
GO

-- =============================================
-- 1. ADMIN AUTHENTICATION & AUTHORIZATION
-- =============================================

-- 1.1: Check if user is Admin
CREATE OR ALTER FUNCTION fn_IsAdmin
(
    @UserID INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @IsAdmin BIT = 0;
    
    IF EXISTS (
        SELECT 1 FROM Users 
        WHERE UserID = @UserID 
        AND UserType = 'Admin' 
        AND IsActive = 1
    )
        SET @IsAdmin = 1;
    
    RETURN @IsAdmin;
END
GO

-- 1.2 Procedure: Admin Login
CREATE OR ALTER PROCEDURE sp_AdminLogin
    @Email NVARCHAR(100),
    @Password VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        UserID,
        FullName,
        Email,
        UserType,
        'Login Success' AS Status
    FROM Users u
    WHERE u.Email = @Email
        AND u.PasswordHash = HASHBYTES('SHA2_256', @Password)
        AND u.UserType IN ('Admin', 'Staff')
        AND u.IsActive = 1;
    
    IF @@ROWCOUNT = 0
        SELECT 0 AS UserID, 'Invalid login/You do not have access' AS Status;
END
GO

-- =============================================
-- 2. USER MANAGEMENT (CRUD)
-- =============================================

-- 2.1 View all users with statistics
CREATE OR ALTER PROCEDURE sp_Admin_GetAllUsers
    @UserType NVARCHAR(20) = NULL,
    @IsActive BIT = NULL,
    @SearchTerm NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        u.UserID,
        u.FullName,
        u.Email,
        u.PhoneNumber,
        u.UserType,
        u.IsActive,
        u.CreatedAt,
        COUNT(DISTINCT b.BookingID) AS TotalBookings,
        SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS TotalSpent,
        MAX(b.BookingDate) AS LastBookingDate
    FROM Users u
    LEFT JOIN Bookings b ON u.UserID = b.UserID
    WHERE (@UserType IS NULL OR u.UserType = @UserType)
        AND (@IsActive IS NULL OR u.IsActive = @IsActive)
        AND (@SearchTerm IS NULL OR 
             u.FullName LIKE '%' + @SearchTerm + '%' OR
             u.Email LIKE '%' + @SearchTerm + '%' OR
             u.PhoneNumber LIKE '%' + @SearchTerm + '%')
    GROUP BY u.UserID, u.FullName, u.Email, u.PhoneNumber, u.UserType, u.IsActive, u.CreatedAt
    ORDER BY u.CreatedAt DESC;
END
GO

-- 2.2 Get user details
CREATE OR ALTER PROCEDURE sp_Admin_GetUserDetails
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- User info
    SELECT 
        UserID,
        FullName,
        Email,
        PhoneNumber,
        UserType,
        IsActive,
        CreatedAt
    FROM Users
    WHERE UserID = @UserID;
    
    -- Booking history
    SELECT 
        b.BookingID,
        b.BookingCode,
        b.BookingDate,
        t.TrainCode,
        dep.StationName AS DepartureStation,
        arr.StationName AS ArrivalStation,
        s.DepartureTime,
        b.TotalAmount,
        b.PaymentStatus,
        b.BookingStatus
    FROM Bookings b
    JOIN Schedules s ON b.ScheduleID = s.ScheduleID
    JOIN Trains t ON s.TrainID = t.TrainID
    JOIN Routes r ON s.RouteID = r.RouteID
    JOIN Stations dep ON r.DepartureStationID = dep.StationID
    JOIN Stations arr ON r.ArrivalStationID = arr.StationID
    WHERE b.UserID = @UserID
    ORDER BY b.BookingDate DESC;
END
GO

-- 2.3 Create user 
CREATE OR ALTER PROCEDURE sp_Admin_CreateUser
    @FullName NVARCHAR(100),
    @Email NVARCHAR(100),
    @PhoneNumber NVARCHAR(20),
    @Password NVARCHAR(255),
    @UserType NVARCHAR(20),
    @AdminUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Check admin permission
        IF dbo.fn_IsAdmin(@AdminUserID) = 0
        BEGIN
            SELECT 'Error' AS Status, 'Insufficient permissions' AS Message;
            RETURN;
        END
        
        -- Validate Email
        IF EXISTS (
            SELECT 1
            FROM Users AS u
            WHERE u.Email = @Email
        )
        BEGIN
            SELECT 'Error' AS Status, N'Email đã tồn tại trong hệ thống' AS Message;
            RETURN;
        END
        
        -- Validate phone number
        IF EXISTS (
            SELECT 1
            FROM Users AS u
            WHERE u.PhoneNumber = @PhoneNumber
        )
        BEGIN
            SELECT 'Error' AS Status, N'Số điện thoại đã tồn tại trong hệ thống' AS Message;
            RETURN;
        END
        INSERT INTO Users (FullName, Email, PhoneNumber, PasswordHash, UserType)
        VALUES (@FullName, @Email, @PhoneNumber, HASHBYTES('SHA2_256', @Password), @UserType);
        
        SELECT 'Success' AS Status, SCOPE_IDENTITY() AS NewUserID;
    END TRY
    BEGIN CATCH
        SELECT 'Error' AS Status, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- 2.4 Update user
CREATE OR ALTER PROCEDURE sp_Admin_UpdateUser
    @UserID INT,
    @FullName NVARCHAR(100),
    @Email NVARCHAR(100),
    @PhoneNumber NVARCHAR(20),
    @UserType NVARCHAR(20),
    @IsActive BIT,
    @AdminUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF dbo.fn_IsAdmin(@AdminUserID) = 0
        BEGIN
            SELECT 'Error' AS Status, 'Insufficient permissions' AS Message;
            RETURN;
        END
        
        UPDATE Users
        SET FullName = @FullName,
            Email = @Email,
            PhoneNumber = @PhoneNumber,
            UserType = @UserType,
            IsActive = @IsActive
        WHERE UserID = @UserID;
        
        SELECT 'Success' AS Status, @@ROWCOUNT AS RowsAffected;
    END TRY
    BEGIN CATCH
        SELECT 'Error' AS Status, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- 2.5 Delete user (Soft delete)
CREATE OR ALTER PROCEDURE sp_Admin_DeleteUser
    @UserID INT,
    @AdminUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF dbo.fn_IsAdmin(@AdminUserID) = 0
        BEGIN
            SELECT 'Error' AS Status, 'Insufficient permissions' AS Message;
            RETURN;
        END
        
        -- Cannot delete user with active bookings
        IF EXISTS (
            SELECT 1 FROM Bookings 
            WHERE UserID = @UserID 
            AND BookingStatus = 'Active'
        )
        BEGIN
            SELECT 'Error' AS Status, 'Cannot delete user with active bookings' AS Message;
            RETURN;
        END
        
        UPDATE Users
        SET IsActive = 0
        WHERE UserID = @UserID;
        
        SELECT 'Success' AS Status;
    END TRY
    BEGIN CATCH
        SELECT 'Error' AS Status, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- =============================================
-- 3. STATION MANAGEMENT (CRUD)
-- =============================================

-- 3.1 Get all stations
CREATE OR ALTER PROCEDURE sp_Admin_GetAllStations
    @IsActive BIT = NULL,
    @SearchTerm NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        s.StationID,
        s.StationCode,
        s.StationName,
        s.City,
        s.Province,
        s.Address,
        s.IsActive,
        COUNT(DISTINCT r1.RouteID) AS DepartureRoutes,
        COUNT(DISTINCT r2.RouteID) AS ArrivalRoutes
    FROM Stations s
    LEFT JOIN Routes r1 ON s.StationID = r1.DepartureStationID
    LEFT JOIN Routes r2 ON s.StationID = r2.ArrivalStationID
    WHERE (@IsActive IS NULL OR s.IsActive = @IsActive)
        AND (@SearchTerm IS NULL OR 
             s.StationName LIKE '%' + @SearchTerm + '%' OR
             s.StationCode LIKE '%' + @SearchTerm + '%' OR
             s.City LIKE '%' + @SearchTerm + '%')
    GROUP BY s.StationID, s.StationCode, s.StationName, s.City, s.Province, s.Address, s.IsActive
    ORDER BY s.StationName;
END
GO

-- 3.2 Delete station
CREATE OR ALTER PROCEDURE sp_Admin_DeleteStation
    @StationID INT,
    @AdminUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF dbo.fn_IsAdmin(@AdminUserID) = 0
        BEGIN
            SELECT 'Error' AS Status, 'Insufficient permissions' AS Message;
            RETURN;
        END
        
        -- Check if station is used in routes
        IF EXISTS (
            SELECT 1 FROM Routes 
            WHERE DepartureStationID = @StationID OR ArrivalStationID = @StationID
        )
        BEGIN
            SELECT 'Error' AS Status, 'Cannot delete station used in routes' AS Message;
            RETURN;
        END
        
        UPDATE Stations
        SET IsActive = 0
        WHERE StationID = @StationID;
        
        SELECT 'Success' AS Status;
    END TRY
    BEGIN CATCH
        SELECT 'Error' AS Status, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- =============================================
-- 4. TRAIN MANAGEMENT (CRUD)
-- =============================================

-- 4.1 Get all trains
CREATE OR ALTER PROCEDURE sp_Admin_GetAllTrains
    @IsActive BIT = NULL,
    @TrainType NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        t.TrainID,
        t.TrainCode,
        t.TrainName,
        t.TrainType,
        t.TotalCoaches,
        t.IsActive,
        COUNT(DISTINCT c.CoachID) AS ConfiguredCoaches,
        SUM(c.TotalSeats) AS TotalSeats,
        COUNT(DISTINCT s.ScheduleID) AS UpcomingSchedules
    FROM Trains t
    LEFT JOIN Coaches c ON t.TrainID = c.TrainID
    LEFT JOIN Schedules s ON t.TrainID = s.TrainID AND s.Status = 'Scheduled' AND s.DepartureTime > GETDATE()
    WHERE (@IsActive IS NULL OR t.IsActive = @IsActive)
        AND (@TrainType IS NULL OR t.TrainType = @TrainType)
    GROUP BY t.TrainID, t.TrainCode, t.TrainName, t.TrainType, t.TotalCoaches, t.IsActive
    ORDER BY t.TrainCode;
END
GO

-- 4.2 Create train
CREATE OR ALTER PROCEDURE sp_Admin_CreateTrain
    @TrainCode NVARCHAR(20),
    @TrainName NVARCHAR(100),
    @TrainType NVARCHAR(50),
    @TotalCoaches INT,
    @AdminUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF dbo.fn_IsAdmin(@AdminUserID) = 0
        BEGIN
            SELECT 'Error' AS Status, 'Insufficient permissions' AS Message;
            RETURN;
        END
        
        INSERT INTO Trains (TrainCode, TrainName, TrainType, TotalCoaches)
        VALUES (@TrainCode, @TrainName, @TrainType, @TotalCoaches);
        
        SELECT 'Success' AS Status, SCOPE_IDENTITY() AS NewTrainID;
    END TRY
    BEGIN CATCH
        SELECT 'Error' AS Status, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- 4.3 Update train
CREATE OR ALTER PROCEDURE sp_Admin_UpdateTrain
    @TrainID INT,
    @TrainCode NVARCHAR(20),
    @TrainName NVARCHAR(100),
    @TrainType NVARCHAR(50),
    @TotalCoaches INT,
    @IsActive BIT,
    @AdminUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF dbo.fn_IsAdmin(@AdminUserID) = 0
        BEGIN
            SELECT 'Error' AS Status, 'Insufficient permissions' AS Message;
            RETURN;
        END
        
        UPDATE Trains
        SET TrainCode = @TrainCode,
            TrainName = @TrainName,
            TrainType = @TrainType,
            TotalCoaches = @TotalCoaches,
            IsActive = @IsActive
        WHERE TrainID = @TrainID;
        
        SELECT 'Success' AS Status;
    END TRY
    BEGIN CATCH
        SELECT 'Error' AS Status, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- 4.4 Delete train
CREATE OR ALTER PROCEDURE sp_Admin_DeleteTrain
    @TrainID INT,
    @AdminUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF dbo.fn_IsAdmin(@AdminUserID) = 0
        BEGIN
            SELECT 'Error' AS Status, 'Insufficient permissions' AS Message;
            RETURN;
        END
        
        -- Check if train has upcoming schedules
        IF EXISTS (
            SELECT 1 FROM Schedules 
            WHERE TrainID = @TrainID 
            AND Status = 'Scheduled' 
            AND DepartureTime > GETDATE()
        )
        BEGIN
            SELECT 'Error' AS Status, 'Cannot delete train with upcoming schedules' AS Message;
            RETURN;
        END
        
        UPDATE Trains
        SET IsActive = 0
        WHERE TrainID = @TrainID;
        
        SELECT 'Success' AS Status;
    END TRY
    BEGIN CATCH
        SELECT 'Error' AS Status, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- =============================================
-- 5. ROUTE MANAGEMENT (CRUD)
-- =============================================

-- 5.1 Get all routes
CREATE OR ALTER PROCEDURE sp_Admin_GetAllRoutes
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        r.RouteID,
        r.RouteCode,
        r.DepartureStationID,
        dep.StationName AS DepartureStation,
        dep.StationCode AS DepartureStationCode,
        r.ArrivalStationID,
        arr.StationName AS ArrivalStation,
        arr.StationCode AS ArrivalStationCode,
        r.Distance,
        r.EstimatedDuration,
        r.IsActive,
        COUNT(DISTINCT s.ScheduleID) AS UpcomingSchedules
    FROM Routes r
    JOIN Stations dep ON r.DepartureStationID = dep.StationID
    JOIN Stations arr ON r.ArrivalStationID = arr.StationID
    LEFT JOIN Schedules s ON r.RouteID = s.RouteID AND s.Status = 'Scheduled' AND s.DepartureTime > GETDATE()
    WHERE (@IsActive IS NULL OR r.IsActive = @IsActive)
    GROUP BY r.RouteID, r.RouteCode, r.DepartureStationID, dep.StationName, dep.StationCode,
             r.ArrivalStationID, arr.StationName, arr.StationCode, r.Distance, r.EstimatedDuration, r.IsActive
    ORDER BY r.RouteCode;
END
GO

-- 5.2 Create route
CREATE OR ALTER PROCEDURE sp_Admin_CreateRoute
    @RouteCode NVARCHAR(20),
    @DepartureStationID INT,
    @ArrivalStationID INT,
    @Distance DECIMAL(8,2),
    @EstimatedDuration INT,
    @AdminUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF dbo.fn_IsAdmin(@AdminUserID) = 0
        BEGIN
            SELECT 'Error' AS Status, 'Insufficient permissions' AS Message;
            RETURN;
        END
        
        IF @DepartureStationID = @ArrivalStationID
        BEGIN
            SELECT 'Error' AS Status, 'Departure and arrival stations must be different' AS Message;
            RETURN;
        END
        
        INSERT INTO Routes (RouteCode, DepartureStationID, ArrivalStationID, Distance, EstimatedDuration)
        VALUES (@RouteCode, @DepartureStationID, @ArrivalStationID, @Distance, @EstimatedDuration);
        
        SELECT 'Success' AS Status, SCOPE_IDENTITY() AS NewRouteID;
    END TRY
    BEGIN CATCH
        SELECT 'Error' AS Status, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- 5.3 Update route
CREATE OR ALTER PROCEDURE sp_Admin_UpdateRoute
    @RouteID INT,
    @RouteCode NVARCHAR(20),
    @Distance DECIMAL(8,2),
    @EstimatedDuration INT,
    @IsActive BIT,
    @AdminUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF dbo.fn_IsAdmin(@AdminUserID) = 0
        BEGIN
            SELECT 'Error' AS Status, 'Insufficient permissions' AS Message;
            RETURN;
        END
        
        UPDATE Routes
        SET RouteCode = @RouteCode,
            Distance = @Distance,
            EstimatedDuration = @EstimatedDuration,
            IsActive = @IsActive
        WHERE RouteID = @RouteID;
        
        SELECT 'Success' AS Status;
    END TRY
    BEGIN CATCH
        SELECT 'Error' AS Status, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- =============================================
-- 6. SCHEDULE MANAGEMENT (CRUD)
-- =============================================

-- 6.1 Get all schedules
CREATE OR ALTER PROCEDURE sp_Admin_GetAllSchedules
    @Status NVARCHAR(20) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @TrainID INT = NULL,
    @RouteID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        s.ScheduleID,
        s.DepartureTime,
        s.ArrivalTime,
        t.TrainCode,
        t.TrainName,
        dep.StationName AS DepartureStation,
        arr.StationName AS ArrivalStation,
        r.Distance,
        s.BasePrice,
        s.AvailableSeats,
        s.Status,
        COUNT(DISTINCT b.BookingID) AS TotalBookings,
        SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS Revenue
    FROM Schedules s
    JOIN Trains t ON s.TrainID = t.TrainID
    JOIN Routes r ON s.RouteID = r.RouteID
    JOIN Stations dep ON r.DepartureStationID = dep.StationID
    JOIN Stations arr ON r.ArrivalStationID = arr.StationID
    LEFT JOIN Bookings b ON s.ScheduleID = b.ScheduleID
    WHERE (@Status IS NULL OR s.Status = @Status)
        AND (@StartDate IS NULL OR CAST(s.DepartureTime AS DATE) >= @StartDate)
        AND (@EndDate IS NULL OR CAST(s.DepartureTime AS DATE) <= @EndDate)
        AND (@TrainID IS NULL OR s.TrainID = @TrainID)
        AND (@RouteID IS NULL OR s.RouteID = @RouteID)
    GROUP BY s.ScheduleID, s.DepartureTime, s.ArrivalTime, t.TrainCode, t.TrainName,
             dep.StationName, arr.StationName, r.Distance, s.BasePrice, s.AvailableSeats, s.Status
    ORDER BY s.DepartureTime DESC;
END
GO

-- 6.2 Delete schedule (with all related bookings cancellation)
CREATE OR ALTER PROCEDURE sp_Admin_DeleteSchedule
    @ScheduleID INT,
    @Reason NVARCHAR(500),
    @AdminUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF dbo.fn_IsAdmin(@AdminUserID) = 0
        BEGIN
            SELECT 'Error' AS Status, 'Insufficient permissions' AS Message;
            RETURN;
        END
        
        EXEC sp_CancelSchedule @ScheduleID, @Reason;
        
        SELECT 'Success' AS Status;
    END TRY
    BEGIN CATCH
        SELECT 'Error' AS Status, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- =============================================
-- 7. BOOKING MANAGEMENT
-- =============================================

-- 7.1 Get all bookings with filters
CREATE OR ALTER PROCEDURE sp_Admin_GetAllBookings
    @BookingStatus NVARCHAR(20) = NULL,
    @PaymentStatus NVARCHAR(20) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @SearchTerm NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        b.BookingID,
        b.BookingCode,
        b.BookingDate,
        u.FullName AS CustomerName,
        u.Email,
        u.PhoneNumber,
        t.TrainCode,
        dep.StationName AS DepartureStation,
        arr.StationName AS ArrivalStation,
        s.DepartureTime,
        s.ArrivalTime,
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
    WHERE (@BookingStatus IS NULL OR b.BookingStatus = @BookingStatus)
        AND (@PaymentStatus IS NULL OR b.PaymentStatus = @PaymentStatus)
        AND (@StartDate IS NULL OR CAST(b.BookingDate AS DATE) >= @StartDate)
        AND (@EndDate IS NULL OR CAST(b.BookingDate AS DATE) <= @EndDate)
        AND (@SearchTerm IS NULL OR 
             b.BookingCode LIKE '%' + @SearchTerm + '%' OR
             u.FullName LIKE '%' + @SearchTerm + '%' OR
             u.Email LIKE '%' + @SearchTerm + '%')
    GROUP BY b.BookingID, b.BookingCode, b.BookingDate, u.FullName, u.Email, u.PhoneNumber,
             t.TrainCode, dep.StationName, arr.StationName, s.DepartureTime, s.ArrivalTime,
             b.TotalAmount, b.PaymentStatus, b.BookingStatus
    ORDER BY b.BookingDate DESC;
END
GO

-- 7.2 Force cancel booking (Admin override)
CREATE OR ALTER PROCEDURE sp_Admin_CancelBooking
    @BookingID INT,
    @Reason NVARCHAR(500),
    @AdminUserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF dbo.fn_IsAdmin(@AdminUserID) = 0
        BEGIN
            SELECT 'Error' AS Status, 'Insufficient permissions' AS Message;
            RETURN;
        END
        
        EXEC sp_CancelBooking @BookingID, @Reason;
        
        SELECT 'Success' AS Status;
    END TRY
    BEGIN CATCH
        SELECT 'Error' AS Status, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- =============================================
-- 8. STATISTICAL VIEWS
-- =============================================

-- 8.1 Dashboard Overview
CREATE OR ALTER PROCEDURE sp_Admin_DashboardOverview
    @DateRange INT = 30 -- Last N days
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartDate DATE = DATEADD(DAY, -@DateRange, GETDATE());
    
    -- Overall statistics
    SELECT 
        COUNT(DISTINCT b.BookingID) AS TotalBookings,
        COUNT(DISTINCT CASE WHEN b.BookingStatus = 'Active' THEN b.BookingID END) AS ActiveBookings,
        COUNT(DISTINCT tk.TicketID) AS TotalTickets,
        SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS TotalRevenue,
        COUNT(DISTINCT b.UserID) AS UniqueCustomers,
        COUNT(DISTINCT s.ScheduleID) AS TotalSchedules,
        AVG(b.TotalAmount) AS AverageBookingValue
    FROM Bookings b
    LEFT JOIN Tickets tk ON b.BookingID = tk.BookingID
    LEFT JOIN Schedules s ON b.ScheduleID = s.ScheduleID
    WHERE CAST(b.BookingDate AS DATE) >= @StartDate;
    
    -- Revenue by day (last 30 days)
    SELECT 
        CAST(b.BookingDate AS DATE) AS BookingDate,
        COUNT(DISTINCT b.BookingID) AS Bookings,
        SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS Revenue
    FROM Bookings b
    WHERE CAST(b.BookingDate AS DATE) >= @StartDate
    GROUP BY CAST(b.BookingDate AS DATE)
    ORDER BY BookingDate DESC;
    
    -- Top routes
    SELECT TOP 5
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
    WHERE CAST(b.BookingDate AS DATE) >= @StartDate
        AND b.PaymentStatus = 'Paid'
    GROUP BY r.RouteCode, dep.StationName, arr.StationName
    ORDER BY Revenue DESC;
    
    -- Recent bookings
    SELECT TOP 10
        b.BookingCode,
        u.FullName,
        t.TrainCode,
        dep.StationName AS DepartureStation,
        arr.StationName AS ArrivalStation,
        b.TotalAmount,
        b.BookingStatus,
        b.BookingDate
    FROM Bookings b
    JOIN Users u ON b.UserID = u.UserID
    JOIN Schedules s ON b.ScheduleID = s.ScheduleID
    JOIN Trains t ON s.TrainID = t.TrainID
    JOIN Routes r ON s.RouteID = r.RouteID
    JOIN Stations dep ON r.DepartureStationID = dep.StationID
    JOIN Stations arr ON r.ArrivalStationID = arr.StationID
    ORDER BY b.BookingDate DESC;
END
GO

-- 8.2 Revenue Analytics
CREATE OR ALTER PROCEDURE sp_Admin_RevenueAnalytics
    @StartDate DATE,
    @EndDate DATE,
    @GroupBy NVARCHAR(20) = 'Day' -- Day, Week, Month
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @GroupBy = 'Day'
    BEGIN
        SELECT 
            CAST(b.BookingDate AS DATE) AS Period,
            COUNT(DISTINCT b.BookingID) AS TotalBookings,
            COUNT(tk.TicketID) AS TotalTickets,
            SUM(b.TotalAmount) AS TotalRevenue,
            SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS PaidRevenue,
            SUM(CASE WHEN b.BookingStatus = 'Cancelled' THEN b.TotalAmount ELSE 0 END) AS CancelledRevenue
        FROM Bookings b
        LEFT JOIN Tickets tk ON b.BookingID = tk.BookingID
        WHERE CAST(b.BookingDate AS DATE) BETWEEN @StartDate AND @EndDate
        GROUP BY CAST(b.BookingDate AS DATE)
        ORDER BY Period;
    END
    ELSE IF @GroupBy = 'Week'
    BEGIN
        SELECT 
            DATEPART(YEAR, b.BookingDate) AS Year,
            DATEPART(WEEK, b.BookingDate) AS Week,
            MIN(CAST(b.BookingDate AS DATE)) AS WeekStart,
            COUNT(DISTINCT b.BookingID) AS TotalBookings,
            COUNT(tk.TicketID) AS TotalTickets,
            SUM(b.TotalAmount) AS TotalRevenue,
            SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS PaidRevenue
        FROM Bookings b
        LEFT JOIN Tickets tk ON b.BookingID = tk.BookingID
        WHERE CAST(b.BookingDate AS DATE) BETWEEN @StartDate AND @EndDate
        GROUP BY DATEPART(YEAR, b.BookingDate), DATEPART(WEEK, b.BookingDate)
        ORDER BY Year, Week;
    END
    ELSE IF @GroupBy = 'Month'
    BEGIN
        SELECT 
            DATEPART(YEAR, b.BookingDate) AS Year,
            DATEPART(MONTH, b.BookingDate) AS Month,
            DATENAME(MONTH, b.BookingDate) AS MonthName,
            COUNT(DISTINCT b.BookingID) AS TotalBookings,
            COUNT(tk.TicketID) AS TotalTickets,
            SUM(b.TotalAmount) AS TotalRevenue,
            SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS PaidRevenue
        FROM Bookings b
        LEFT JOIN Tickets tk ON b.BookingID = tk.BookingID
        WHERE CAST(b.BookingDate AS DATE) BETWEEN @StartDate AND @EndDate
        GROUP BY DATEPART(YEAR, b.BookingDate), DATEPART(MONTH, b.BookingDate), DATENAME(MONTH, b.BookingDate)
        ORDER BY Year, Month;
    END
END
GO

-- 8.3 Seat Class Performance
CREATE OR ALTER PROCEDURE sp_Admin_SeatClassAnalytics
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
        MIN(tk.TicketPrice) AS MinPrice,
        MAX(tk.TicketPrice) AS MaxPrice,
        CAST(COUNT(tk.TicketID) * 100.0 / NULLIF(SUM(COUNT(tk.TicketID)) OVER(), 0) AS DECIMAL(5,2)) AS PercentageOfTotal
    FROM Tickets tk
    JOIN Bookings b ON tk.BookingID = b.BookingID
    JOIN Seats st ON tk.SeatID = st.SeatID
    JOIN Coaches c ON st.CoachID = c.CoachID
    JOIN SeatClasses sc ON c.SeatClassID = sc.SeatClassID
    WHERE CAST(b.BookingDate AS DATE) BETWEEN @StartDate AND @EndDate
        AND b.PaymentStatus = 'Paid'
    GROUP BY sc.ClassName, sc.SeatClassID
    ORDER BY TotalRevenue DESC;
END
GO

-- 8.4 Train Utilization Report
CREATE OR ALTER PROCEDURE sp_Admin_TrainUtilization
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        t.TrainCode,
        t.TrainName,
        COUNT(DISTINCT s.ScheduleID) AS TotalTrips,
        SUM(CASE WHEN s.Status = 'Completed' THEN 1 ELSE 0 END) AS CompletedTrips,
        SUM(CASE WHEN s.Status = 'Cancelled' THEN 1 ELSE 0 END) AS CancelledTrips,
        AVG(CAST((t.TotalCoaches * 50 - s.AvailableSeats) AS FLOAT) / NULLIF(t.TotalCoaches * 50, 0) * 100) AS AverageOccupancy,
        COUNT(DISTINCT b.BookingID) AS TotalBookings,
        SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS TotalRevenue
    FROM Trains t
    LEFT JOIN Schedules s ON t.TrainID = s.TrainID AND CAST(s.DepartureTime AS DATE) BETWEEN @StartDate AND @EndDate
    LEFT JOIN Bookings b ON s.ScheduleID = b.ScheduleID
    GROUP BY t.TrainCode, t.TrainName, t.TotalCoaches
    ORDER BY TotalRevenue DESC;
END
GO

-- 8.5 Route Performance (FIXED)
CREATE OR ALTER PROCEDURE sp_Admin_RoutePerformance
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        r.RouteCode,
        dep.StationName AS DepartureStation,
        arr.StationName AS ArrivalStation,
        r.Distance,
        COUNT(DISTINCT s.ScheduleID) AS TotalSchedules,
        COUNT(DISTINCT b.BookingID) AS TotalBookings,
        COUNT(tk.TicketID) AS TotalTickets,
        SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS TotalRevenue,
        AVG(b.TotalAmount) AS AverageBookingValue,
        AVG(s.BasePrice) AS AverageBasePrice
    FROM Routes r
    JOIN Stations dep ON r.DepartureStationID = dep.StationID
    JOIN Stations arr ON r.ArrivalStationID = arr.StationID
    LEFT JOIN Schedules s ON r.RouteID = s.RouteID 
        AND CAST(s.DepartureTime AS DATE) BETWEEN @StartDate AND @EndDate
    LEFT JOIN Bookings b ON s.ScheduleID = b.ScheduleID
    LEFT JOIN Tickets tk ON b.BookingID = tk.BookingID
    WHERE s.ScheduleID IS NOT NULL
    GROUP BY r.RouteCode, dep.StationName, arr.StationName, r.Distance
    ORDER BY TotalRevenue DESC;
END
GO

-- 8.6 Customer Segmentation (FIXED)
CREATE OR ALTER PROCEDURE sp_Admin_CustomerSegmentation
AS
BEGIN
    SET NOCOUNT ON;
    
    WITH CustomerData AS (
        SELECT 
            u.UserID,
            u.FullName,
            COUNT(DISTINCT b.BookingID) AS TotalBookings,
            SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS TotalSpent
        FROM Users u
        LEFT JOIN Bookings b ON u.UserID = b.UserID
        WHERE u.UserType = 'Customer'
        GROUP BY u.UserID, u.FullName
    ),
    SegmentedData AS (
        SELECT 
            CASE 
                WHEN TotalSpent >= 10000000 THEN 'VIP'
                WHEN TotalSpent >= 5000000 THEN 'Gold'
                WHEN TotalSpent >= 2000000 THEN 'Silver'
                ELSE 'Regular'
            END AS CustomerSegment,
            UserID,
            TotalBookings,
            TotalSpent
        FROM CustomerData
    )
    SELECT 
        CustomerSegment,
        COUNT(UserID) AS CustomerCount,
        AVG(TotalSpent) AS AvgSpent,
        AVG(TotalBookings) AS AvgBookings,
        SUM(TotalSpent) AS TotalRevenue
    FROM SegmentedData
    GROUP BY CustomerSegment
    ORDER BY 
        CASE CustomerSegment
            WHEN 'VIP' THEN 1
            WHEN 'Gold' THEN 2
            WHEN 'Silver' THEN 3
            ELSE 4
        END;
END
GO



-- 8.8 Payment Method Analytics
CREATE OR ALTER PROCEDURE sp_Admin_PaymentAnalytics
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
        MIN(p.Amount) AS MinAmount,
        MAX(p.Amount) AS MaxAmount,
        SUM(CASE WHEN p.PaymentStatus = 'Success' THEN 1 ELSE 0 END) AS SuccessCount,
        SUM(CASE WHEN p.PaymentStatus = 'Failed' THEN 1 ELSE 0 END) AS FailedCount,
        CAST(SUM(CASE WHEN p.PaymentStatus = 'Success' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(p.PaymentID), 0) AS DECIMAL(5,2)) AS SuccessRate
    FROM Payments p
    WHERE CAST(p.PaymentDate AS DATE) BETWEEN @StartDate AND @EndDate
    GROUP BY p.PaymentMethod
    ORDER BY TotalAmount DESC;
END
GO

-- 8.9 Peak Hours Analysis
CREATE OR ALTER PROCEDURE sp_Admin_PeakHoursAnalysis
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Booking by hour
    SELECT 
        DATEPART(HOUR, BookingDate) AS Hour,
        COUNT(BookingID) AS BookingCount,
        SUM(TotalAmount) AS Revenue
    FROM Bookings
    WHERE CAST(BookingDate AS DATE) BETWEEN @StartDate AND @EndDate
    GROUP BY DATEPART(HOUR, BookingDate)
    ORDER BY Hour;
    
    -- Booking by day of week
    SELECT 
        DATENAME(WEEKDAY, BookingDate) AS DayOfWeek,
        DATEPART(WEEKDAY, BookingDate) AS DayNumber,
        COUNT(BookingID) AS BookingCount,
        SUM(TotalAmount) AS Revenue
    FROM Bookings
    WHERE CAST(BookingDate AS DATE) BETWEEN @StartDate AND @EndDate
    GROUP BY DATENAME(WEEKDAY, BookingDate), DATEPART(WEEKDAY, BookingDate)
    ORDER BY DayNumber;
END
GO

-- 8.10 Notification Statistics
CREATE OR ALTER PROCEDURE sp_Admin_NotificationStats
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SET @StartDate = COALESCE(@StartDate, DATEADD(DAY, -30, GETDATE()));
    SET @EndDate = COALESCE(@EndDate, GETDATE());
    
    SELECT 
        NotificationType,
        COUNT(*) AS TotalSent,
        SUM(CASE WHEN IsRead = 1 THEN 1 ELSE 0 END) AS ReadCount,
        SUM(CASE WHEN IsRead = 0 THEN 1 ELSE 0 END) AS UnreadCount,
        CAST(SUM(CASE WHEN IsRead = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS ReadRate
    FROM Notifications
    WHERE CAST(SentAt AS DATE) BETWEEN @StartDate AND @EndDate
    GROUP BY NotificationType
    ORDER BY TotalSent DESC;
END
GO

-- =============================================
-- 9. ADMIN REPORTS
-- =============================================

-- 9.1 Monthly Summary Report
CREATE OR ALTER PROCEDURE sp_Admin_MonthlySummaryReport
    @Year INT,
    @Month INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartDate DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @EndDate DATE = EOMONTH(@StartDate);
    
    PRINT '=================================================';
    PRINT 'MONTHLY SUMMARY REPORT - ' + DATENAME(MONTH, @StartDate) + ' ' + CAST(@Year AS VARCHAR);
    PRINT '=================================================';
    
    -- Revenue summary
    SELECT 'REVENUE SUMMARY' AS Section;
    SELECT 
        COUNT(DISTINCT b.BookingID) AS TotalBookings,
        COUNT(tk.TicketID) AS TotalTickets,
        SUM(b.TotalAmount) AS TotalRevenue,
        SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS CollectedRevenue,
        SUM(CASE WHEN b.BookingStatus = 'Cancelled' THEN b.TotalAmount ELSE 0 END) AS CancelledRevenue,
        AVG(b.TotalAmount) AS AverageBookingValue
    FROM Bookings b
    LEFT JOIN Tickets tk ON b.BookingID = tk.BookingID
    WHERE CAST(b.BookingDate AS DATE) BETWEEN @StartDate AND @EndDate;
    
    -- Top routes
    SELECT 'TOP 5 ROUTES' AS Section;
    SELECT TOP 5
        r.RouteCode,
        dep.StationName + ' → ' + arr.StationName AS Route,
        COUNT(DISTINCT b.BookingID) AS Bookings,
        SUM(CASE WHEN b.PaymentStatus = 'Paid' THEN b.TotalAmount ELSE 0 END) AS Revenue
    FROM Bookings b
    JOIN Schedules s ON b.ScheduleID = s.ScheduleID
    JOIN Routes r ON s.RouteID = r.RouteID
    JOIN Stations dep ON r.DepartureStationID = dep.StationID
    JOIN Stations arr ON r.ArrivalStationID = arr.StationID
    WHERE CAST(b.BookingDate AS DATE) BETWEEN @StartDate AND @EndDate
        AND b.PaymentStatus = 'Paid'
    GROUP BY r.RouteCode, dep.StationName, arr.StationName
    ORDER BY Revenue DESC;
    
    -- Customer statistics
    SELECT 'CUSTOMER STATISTICS' AS Section;
    SELECT 
        COUNT(DISTINCT b.UserID) AS UniqueCustomers,
        COUNT(DISTINCT CASE WHEN FirstBooking.FirstDate >= @StartDate THEN b.UserID END) AS NewCustomers,
        COUNT(DISTINCT CASE WHEN RepeatCustomer.BookingCount > 1 THEN b.UserID END) AS ReturningCustomers
    FROM Bookings b
    LEFT JOIN (
        SELECT UserID, MIN(BookingDate) AS FirstDate
        FROM Bookings
        GROUP BY UserID
    ) FirstBooking ON b.UserID = FirstBooking.UserID
    LEFT JOIN (
        SELECT UserID, COUNT(*) AS BookingCount
        FROM Bookings
        WHERE CAST(BookingDate AS DATE) BETWEEN @StartDate AND @EndDate
        GROUP BY UserID
    ) RepeatCustomer ON b.UserID = RepeatCustomer.UserID
    WHERE CAST(b.BookingDate AS DATE) BETWEEN @StartDate AND @EndDate;
END
GO

-- 9.2 Export All Data for Analysis
CREATE OR ALTER PROCEDURE sp_Admin_ExportBookingData
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        b.BookingID,
        b.BookingCode,
        b.BookingDate,
        b.BookingStatus,
        b.PaymentStatus,
        u.UserID,
        u.FullName AS CustomerName,
        u.Email,
        u.PhoneNumber,
        u.UserType,
        s.ScheduleID,
        s.DepartureTime,
        s.ArrivalTime,
        t.TrainCode,
        t.TrainName,
        t.TrainType,
        r.RouteCode,
        dep.StationCode AS DepartureStationCode,
        dep.StationName AS DepartureStation,
        arr.StationCode AS ArrivalStationCode,
        arr.StationName AS ArrivalStation,
        r.Distance,
        r.EstimatedDuration,
        s.BasePrice,
        b.TotalAmount,
        tk.TicketID,
        tk.PassengerName,
        c.CoachNumber,
        st.SeatNumber,
        sc.ClassName AS SeatClass,
        tk.TicketPrice,
        p.PaymentMethod,
        p.PaymentDate,
        p.TransactionID,
        DATEDIFF(DAY, b.BookingDate, s.DepartureTime) AS DaysBeforeDeparture,
        CASE WHEN b.CancelledAt IS NOT NULL 
             THEN DATEDIFF(HOUR, b.CancelledAt, s.DepartureTime) 
             ELSE NULL 
        END AS HoursBeforeDepartureCancelled
    FROM Bookings b
    JOIN Users u ON b.UserID = u.UserID
    JOIN Schedules s ON b.ScheduleID = s.ScheduleID
    JOIN Trains t ON s.TrainID = t.TrainID
    JOIN Routes r ON s.RouteID = r.RouteID
    JOIN Stations dep ON r.DepartureStationID = dep.StationID
    JOIN Stations arr ON r.ArrivalStationID = arr.StationID
    LEFT JOIN Tickets tk ON b.BookingID = tk.BookingID
    LEFT JOIN Seats st ON tk.SeatID = st.SeatID
    LEFT JOIN Coaches c ON st.CoachID = c.CoachID
    LEFT JOIN SeatClasses sc ON c.SeatClassID = sc.SeatClassID
    LEFT JOIN Payments p ON b.BookingID = p.BookingID AND p.PaymentStatus = 'Success'
    WHERE CAST(b.BookingDate AS DATE) BETWEEN @StartDate AND @EndDate
    ORDER BY b.BookingDate DESC, b.BookingID, tk.TicketID;
END
GO


