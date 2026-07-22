# Self-Order Request Feature - Implementation Guide

## Overview
This feature allows customers in dine-in orders to send requests to staff (e.g., for cutlery, water, napkins, etc.) directly from the order display interface.

## API Endpoints

The following REST API endpoints have been implemented on the backend:

### 1. Create a Self-Order Request
```
POST /api/v1/self-order-requests
```

**Request Body:**
```json
{
  "orderNumber": "ORD-1001",
  "tableNumber": "T-05",
  "store": "64f...",
  "selectedNeeds": ["Cutlery", "Water"],
  "other": true,
  "customRequest": "Extra sauce",
  "customerName": "Ali",
  "phone": "03001234567"
}
```

**Response:** Created SelfOrderRequest object with `_id`, status, timestamps

### 2. Get All Requests (Admin/Staff)
```
GET /api/v1/self-order-requests?page=1&limit=10&status=Pending&store=...
```

**Query Parameters:**
- `page` (integer): Page number (default: 1)
- `limit` (integer): Results per page (default: 10)
- `status` (string): Filter by status (Pending, Accepted, Completed, etc.)
- `store` (string): Filter by store ID

**Response:**
```json
{
  "data": [
    {
      "_id": "...",
      "orderNumber": "ORD-1001",
      "tableNumber": "T-05",
      "selectedNeeds": ["Cutlery", "Water"],
      "status": "Pending",
      "createdAt": "2024-01-15T10:30:00Z"
    }
  ],
  "total": 25,
  "page": 1,
  "limit": 10,
  "pages": 3
}
```

### 3. Get Single Request
```
GET /api/v1/self-order-requests/:id
```

### 4. Update Request Status (Admin/Staff)
```
PATCH /api/v1/self-order-requests/:id/status
```

**Request Body:**
```json
{
  "status": "Completed"
}
```

## Files Created/Modified

### New Files Created:

1. **lib/models/self_order_request_model.dart**
   - `SelfOrderRequest` class with properties and serialization
   - `SelfOrderRequestsResponse` class for paginated responses

2. **lib/services/self_order_request_service.dart**
   - `SelfOrderRequestService` with singleton pattern
   - Methods:
     - `createRequest()` - Submit a new request
     - `getRequests()` - Fetch paginated requests (admin)
     - `getRequestById()` - Get request details
     - `updateRequestStatus()` - Update request status (admin)
     - `getRequestsByOrderNumber()` - Get requests for specific order

3. **lib/modals/self_order_request_modal.dart**
   - `SelfOrderRequestModal` - Beautiful dialog UI for customers
   - Pre-defined options: Cutlery, Water, Napkins, Sauce, Condiments, Straws, Plates, Utensils, Toothpicks, Wet Wipes
   - Custom request field for other needs
   - Validation and error handling

4. **lib/widgets/request_bell_button.dart**
   - `RequestBellButton` - Reusable button widget with bell icon
   - Shows notification badge when request is sent
   - Customizable size and padding
   - Opens request modal on tap

### Modified Files:

1. **lib/core/constants/api_constants.dart**
   - Added endpoint: `static const String selfOrderRequests = '/self-order-requests';`

2. **lib/pages/orders/details/order_details_breadcrumb.dart**
   - Added import for `RequestBellButton`
   - Added request bell button in the action buttons row
   - Only shows for dine-in orders (`orderType == 'Dine-in'`)

3. **lib/pages/orders/list/orders_page.dart**
   - Added import for `RequestBellButton`
   - Added request bell button in the order list table (last column)
   - Only shows for dine-in orders
   - Button is compact (no label) to fit in table

## UI Components

### RequestBellButton Widget
A reusable button with:
- **Bell icon** (🔔) with amber styling
- **Optional label** below the button
- **Notification badge** (red dot) after request is sent
- **Configurable size and padding**
- Opens `SelfOrderRequestModal` when clicked

### SelfOrderRequestModal Dialog
A beautiful modal with:
- **Header** with bell icon and order number
- **Predefined options grid** as filter chips
- **"Other" checkbox** with text area for custom requests
- **Cancel and Send buttons**
- **Loading state** while submitting
- **Input validation**

## Usage

### For Customers:

1. **From Order List:**
   - Navigate to Orders page
   - Find your dine-in order
   - Click the bell icon in the "Quick View" column
   - Select items needed or enter custom request
   - Click "Send Request"

2. **From Order Details:**
   - Navigate to Order Details page
   - Click the "Request" bell button in the action buttons row
   - Follow the same modal flow

### For Admin/Staff:

1. **View Requests:**
   - Access `/api/v1/self-order-requests` endpoint
   - Filter by status, store, with pagination

2. **Update Request:**
   - Use PATCH `/api/v1/self-order-requests/:id/status` endpoint
   - Change status to "Accepted", "Completed", etc.

## Predefined Request Options

```
1. Cutlery
2. Water
3. Napkins
4. Sauce
5. Condiments
6. Straws
7. Plates
8. Utensils
9. Toothpicks
10. Wet Wipes
```

These can be customized in `lib/modals/self_order_request_modal.dart`

## Error Handling

- **Validation errors** show snackbar messages
- **API errors** are caught and displayed to user
- **Network errors** are handled gracefully
- **Empty state** messages guide users

## Features

✅ **For Customers:**
- Easy-to-use bell button interface
- Pre-defined common requests
- Custom request text field
- Visual feedback (notification badge)
- Success/error messages

✅ **For Staff/Admin:**
- Paginated request list view
- Status filtering
- Store-specific filtering
- Update request status
- View request details

## Testing

To test the feature:

1. Create a dine-in order
2. Navigate to order details or order list
3. Click the bell icon
4. Select options (e.g., "Cutlery", "Water")
5. Optionally add custom request
6. Click "Send Request"
7. Verify:
   - Notification badge appears
   - Request appears in admin dashboard
   - Status can be updated from admin panel

## Customization

### Change Predefined Options:
Edit `lib/modals/self_order_request_modal.dart` - modify `_predefinedNeeds` list

### Change Button Colors:
Edit `lib/widgets/request_bell_button.dart` - modify color constants

### Change Modal UI:
Edit `lib/modals/self_order_request_modal.dart` - customize styling and layout

## Dependencies

All required dependencies are already in `pubspec.yaml`:
- `flutter` (Material Design)
- `http` (HTTP requests)
- `intl` (Date formatting)

## Error Codes & Messages

| Scenario | Message |
|----------|---------|
| No options selected | "Please select at least one option or add a custom request" |
| Custom request empty | "Please enter your custom request" |
| API submission failed | "Failed to send request: [error message]" |
| Success | "Request sent to staff!" |

## Performance Considerations

- Service uses singleton pattern to avoid duplicate instances
- Requests are sent with minimal payload
- Modal is lightweight and responsive
- No heavy list rendering (modal only, not list)

## Future Enhancements

- Add timestamps to track request response time
- Add request priority levels
- Add sound/notification for staff
- Add request history view for customers
- Add request tracking/status updates for customers
- Integration with WebSocket for real-time updates
