
Use TrainTicketSystem;
Go

-- =============================================
-- FLOW : ADMIN LOGIN & DASHBOARD
-- =============================================


-- =============================================
-- TẠO TÀI KHOẢN ADMIN
-- =============================================
PRINT '--- Tạo tài khoản Admin ---';
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'admin@gmail.com')
BEGIN
    INSERT INTO Users (FullName, Email, PhoneNumber, PasswordHash, UserType, IsActive)
    VALUES (N'Admin System', 'admin@gmail.com', '0981603087', 
            HASHBYTES('SHA2_256', 'Admin@123'), 'Admin', 1);
    PRINT 'Tạo tài khoản admin thành công!';
END
ELSE
    PRINT 'Tài khoản admin đã tồn tại!';
PRINT '';

-- =============================================
-- ĐĂNG NHẬP ADMIN
-- =============================================
PRINT '--- Đăng nhập Admin ---';
EXEC sp_AdminLogin 
    @Email = 'admin@gmail.com', 
    @Password = 'Admin@123';
PRINT '';

-- =============================================
-- XEM TỔNG QUAN DASHBOARD
-- =============================================
PRINT '--- Dashboard  Overview(30 ngày gần nhất) ---';
EXEC sp_Admin_DashboardOverview @DateRange = 30;
PRINT '';

-- =============================================
-- QUẢN LÝ NGƯỜI DÙNG
-- =============================================

DECLARE @AdminID INT;
SELECT @AdminID = UserID FROM Users WHERE Email = 'admin@gmail.com';

-- Xem danh sách tất cả khách hàng
PRINT '--- Xem danh sách tất cả khách hàng ---';
EXEC sp_Admin_GetAllUsers 
    @UserType = 'Customer',   
    @IsActive = 1,               
    @SearchTerm = NULL;        
PRINT '';

-- Tìm kiếm người dùng 
PRINT '--- Tìm kiếm người dùng ---';
EXEC sp_Admin_GetAllUsers 
    @UserType = NULL,     
    @IsActive = NULL,        
    @SearchTerm = 'Test';       
PRINT '';

-- Xem chi tiết thông tin người dùng
PRINT '--- Xem chi tiết người dùng ---';
EXEC sp_Admin_GetUserDetails @UserID = 1;
PRINT '';

-- Tạo tài khoản nhân viên mới
PRINT '--- Tạo tài khoản nhân viên mới ---';
EXEC sp_Admin_CreateUser
    @FullName = N'Xin chào',
    @Email = 'staff123@gmail.com',
    @PhoneNumber = '0918888888',
    @Password = 'Staff@123',
    @UserType = 'Staff',        
    @AdminUserID = @AdminID;     
PRINT '';

-- Cập nhật thông tin người dùng
PRINT '--- Cập nhật thông tin người dùng ---';
DECLARE @StaffID INT;
SELECT @StaffID = UserID FROM Users WHERE Email = 'staff.test@trainticket.com';

EXEC sp_Admin_UpdateUser
    @UserID = @StaffID,
    @FullName = N'Nhân Viên Test Updated',  
    @Email = 'staff.test@trainticket.com',
    @PhoneNumber = '0918888889',          
    @UserType = 'Staff',
    @IsActive = 1,                           
    @AdminUserID = @AdminID;
PRINT '';

-- Xóa người dùng 
PRINT '--- Xóa người dùng ---';
EXEC sp_Admin_DeleteUser
    @UserID = @StaffID,
    @AdminUserID = @AdminID;
PRINT '';

-- =============================================
-- QUẢN LÝ GA TÀU
-- =============================================

-- Xem tất cả ga tàu đang hoạt động
PRINT '--- Xem tất cả ga tàu đang hoạt động ---';
EXEC sp_Admin_GetAllStations 
    @IsActive = 1,             
    @SearchTerm = NULL;
PRINT '';

-- Tìm kiếm ga tàu có chứa "Hà Nội"
PRINT '--- Tìm kiếm ga tàu (Hà Nội) ---';
EXEC sp_Admin_GetAllStations 
    @IsActive = NULL,
    @SearchTerm = N'Hà Nội';
PRINT '';

-- Thêm ga tàu mới
PRINT '--- Thêm ga tàu mới ---';
EXEC sp_AddStation
    @StationCode = 'CT',       
    @StationName = N'Cần Thơ',
    @City = N'Cần Thơ',
    @Province = N'Cần Thơ',
    @Address = N'Đường 30/4';
PRINT '';

-- Cập nhật thông tin ga tàu
PRINT '--- Cập nhật thông tin ga tàu ---';
DECLARE @NewStationID INT;
SELECT @NewStationID = StationID FROM Stations WHERE StationCode = 'CT';

EXEC sp_UpdateStation
    @StationID = @NewStationID,
    @StationName = N'Cần Thơ City',   
    @City = N'Cần Thơ',
    @Province = N'Cần Thơ',
    @Address = N'Số 1, Đường 30/4',      
    @IsActive = 1;
PRINT '';

-- =============================================
-- QUẢN LÝ ĐOÀ TÀU
-- =============================================

-- Xem tất cả đoàn tàu đang hoạt động
PRINT '--- Xem tất cả đoàn tàu đang hoạt động ---';
EXEC sp_Admin_GetAllTrains 
    @IsActive = 1,              
    @TrainType = NULL;          
PRINT '';

-- Tạo đoàn tàu mới
PRINT '--- Tạo đoàn tàu mới ---';
EXEC sp_Admin_CreateTrain
    @TrainCode = 'SE10',        
    @TrainName = N'Thống Nhất SE10',
    @TrainType = 'SE',           
    @TotalCoaches = 10,          
    @AdminUserID = @AdminID;
PRINT '';

-- Cập nhật thông tin đoàn tàu
PRINT '--- Cập nhật thông tin đoàn tàu ---';
DECLARE @NewTrainID INT;
SELECT @NewTrainID = TrainID FROM Trains WHERE TrainCode = 'SE10';

EXEC sp_Admin_UpdateTrain
    @TrainID = @NewTrainID,
    @TrainCode = 'SE10',
    @TrainName = N'Thống Nhất SE10 Updated', 
    @TrainType = 'SE',
    @TotalCoaches = 12,                       
    @IsActive = 1,
    @AdminUserID = @AdminID;
PRINT '';

-- =============================================
-- QUẢN LÝ TUYẾN ĐƯỜNG
-- =============================================

-- Xem tất cả tuyến đường đang hoạt động
PRINT '--- Xem tất cả tuyến đường đang hoạt động ---';
EXEC sp_Admin_GetAllRoutes @IsActive = 1;
PRINT '';

-- Tạo tuyến đường mới 
PRINT '--- Tạo tuyến đường mới ---';
EXEC sp_Admin_CreateRoute
    @RouteCode = 'HN-CT',           
    @DepartureStationID = 1,       
    @ArrivalStationID = @NewStationID,
    @Distance = 1800,                
    @EstimatedDuration = 2400,       
    @AdminUserID = @AdminID;
PRINT '';

-- Cập nhật thông tin tuyến đường
PRINT '--- Cập nhật thông tin tuyến đường ---';
DECLARE @NewRouteID INT;
SELECT @NewRouteID = RouteID FROM Routes WHERE RouteCode = 'HN-CT';

EXEC sp_Admin_UpdateRoute
    @RouteID = @NewRouteID,
    @RouteCode = 'HN-CT',
    @Distance = 1850,            
    @EstimatedDuration = 2500,     
    @IsActive = 1,
    @AdminUserID = @AdminID;
PRINT '';

-- =============================================
-- QUẢN LÝ LỊCH TRÌNH
-- =============================================

-- Xem tất cả lịch trình đã lên lịch
PRINT '--- Xem các chuyến tàu đã lên lịch ---';
EXEC sp_Admin_GetAllSchedules 
    @Status = 'Scheduled',      
    @StartDate = NULL,
    @EndDate = NULL,
    @TrainID = NULL,
    @RouteID = NULL;
PRINT '';

-- Thêm lịch trình mới
PRINT '--- Thêm lịch trình mới ---';
EXEC sp_AddSchedule
    @TrainID = 1,                           
    @RouteID = 1,                       
    @DepartureTime = '2025-12-01 19:00',    
    @ArrivalTime = '2025-12-03 03:00',     
    @BasePrice = 900000;                    
PRINT '';

-- Xem lịch trình theo khoảng thời gian 
PRINT '--- Xem lịch trình ---';
EXEC sp_Admin_GetAllSchedules 
    @Status = NULL,
    @StartDate = '2025-11-01',   
    @EndDate = '2025-11-30',     
    @TrainID = NULL,
    @RouteID = NULL;
PRINT '';

-- =============================================
-- QUẢN LÝ ĐẶT VÉ
-- =============================================

-- Xem tất cả bookings đang hoạt động
PRINT '--- Xem tất cả bookinngs đang hoạt động ---';
EXEC sp_Admin_GetAllBookings
    @BookingStatus = 'Active',  
    @PaymentStatus = NULL,
    @StartDate = NULL,
    @EndDate = NULL,
    @SearchTerm = NULL;
PRINT '';

-- Tìm kiếm đặt vé theo tên 
PRINT '--- Tìm kiếm đặt vé (theo tên) ---';
EXEC sp_Admin_GetAllBookings
    @BookingStatus = NULL,
    @PaymentStatus = NULL,
    @StartDate = NULL,
    @EndDate = NULL,
    @SearchTerm = N'Nguyễn';
PRINT '';

-- Xem đặt vé theo khoảng thời gian (10-11/2025)
PRINT '--- Xem đặt vé (Tháng 10-11/2025) ---';
EXEC sp_Admin_GetAllBookings
    @BookingStatus = NULL,
    @PaymentStatus = 'Paid',        
    @StartDate = '2025-10-01',
    @EndDate = '2025-11-30',
    @SearchTerm = NULL;
PRINT '';

-- =============================================
-- BÁO CÁO THỐNG KÊ
-- =============================================

-- Báo cáo 1: Doanh thu theo ngày
PRINT '--- Báo cáo 1: Doanh thu theo ngày (10-11/2025) ---';
EXEC sp_RevenueByDate 
    @StartDate = '2025-10-01',
    @EndDate = '2025-11-05';
PRINT '';

-- Báo cáo 2: Phân tích doanh thu (theo ngày)
PRINT '--- Báo cáo 2: Phân tích doanh thu (Theo ngày) ---';
EXEC sp_Admin_RevenueAnalytics
    @StartDate = '2025-10-01',
    @EndDate = '2025-11-05',
    @GroupBy = 'Day';            
PRINT '';

-- Báo cáo 3: Phân tích theo hạng ghế
PRINT '--- Báo cáo 3: Hiệu suất theo hạng ghế ---';
EXEC sp_Admin_SeatClassAnalytics
    @StartDate = '2025-10-01',
    @EndDate = '2025-11-05';
PRINT '';

-- Báo cáo 4: Tỷ lệ sử dụng đoàn tàu
PRINT '--- Báo cáo 4: Tỷ lệ sử dụng đoàn tàu ---';
EXEC sp_Admin_TrainUtilization
    @StartDate = '2025-10-01',
    @EndDate = '2025-11-05';
PRINT '';

-- Báo cáo 5: Hiệu suất tuyến đường
PRINT '--- Báo cáo 5: Hiệu suất tuyến đường ---';
EXEC sp_Admin_RoutePerformance
    @StartDate = '2025-10-01',
    @EndDate = '2025-11-05';
PRINT '';

-- Báo cáo 6: Phân khúc khách hàng
PRINT '--- Báo cáo 6: Phân khúc khách hàng ---';
EXEC sp_Admin_CustomerSegmentation;
PRINT '';


-- Báo cáo 8: Phân tích phương thức thanh toán
PRINT '--- Báo cáo 8: Phân tích phương thức thanh toán ---';
EXEC sp_Admin_PaymentAnalytics
    @StartDate = '2025-10-01',
    @EndDate = '2025-11-05';
PRINT '';

-- Báo cáo 9: Phân tích giờ cao điểm
PRINT '--- Báo cáo 9: Phân tích giờ cao điểm ---';
EXEC sp_Admin_PeakHoursAnalysis
    @StartDate = '2025-10-01',
    @EndDate = '2025-11-09';
PRINT '';

-- Báo cáo 10: Thống kê thông báo
PRINT '--- Báo cáo 10: Thống kê thông báo ---';
EXEC sp_Admin_NotificationStats
    @StartDate = '2025-10-01',
    @EndDate = '2025-11-05';
PRINT '';
