# DKStore API Documentation

This document describes the API endpoints used by the DKStore Flutter app.
The client base URL is defined in `lib/config/constant.dart`.

```text
Base URL: https://panel.dkstore.id/api/
```

## Conventions

All requests send:

```http
Accept: application/json
Content-Type: application/json
Authorization: Bearer <token>
```

`Authorization` is included only after login. Multipart endpoints use the same
authorization token with form data.

Most API responses are consumed as JSON maps with a common envelope similar to:

```json
{
  "success": true,
  "message": "Operation completed",
  "data": {}
}
```

Validation errors commonly return HTTP `422`, unauthorized requests return
`401`, forbidden requests return `403`, missing resources return `404`, and
server failures return `500` or `503`.

Many catalogue, cart, store, wishlist, and product endpoints are location-aware.
The app sends `latitude` and `longitude` from the stored user location.

## Authentication

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/login` | No | Login with email or mobile number. |
| POST | `/register` | No | Create a new account. |
| POST | `/verify-user` | No | Check whether an email/mobile value is available or valid. |
| POST | `/forget-password` | No | Request password reset. |
| POST | `/auth/google/callback` | No | Login/register with Firebase Google token. |
| POST | `/auth/apple/callback` | No | Login/register with Firebase Apple token. |
| POST | `/auth/phone/callback` | No | Login/register with Firebase phone token. |
| POST | `/auth/send-otp` | No | Send custom OTP. Route is registered in the client but not currently called. |
| POST | `/auth/verify-otp` | No | Verify custom OTP. Route is registered in the client but not currently called. |
| POST | `/logout` | Yes | Logout current user. |
| DELETE | `/user/delete-account` | Yes | Delete current user account. |

### POST `/login`

Request body:

```json
{
  "email": "user@example.com",
  "mobile": 628123456789,
  "password": "secret",
  "fcm_token": "firebase-cloud-messaging-token",
  "device_type": "android"
}
```

Send either `email` or `mobile`. `device_type` is `android`, `ios`, or
`unknown`.

### POST `/register`

Request body:

```json
{
  "name": "Customer Name",
  "email": "user@example.com",
  "mobile": "628123456789",
  "password": "secret",
  "password_confirmation": "secret",
  "country": "Indonesia",
  "iso_2": "ID",
  "fcm_token": "firebase-cloud-messaging-token",
  "device_type": "android"
}
```

### POST `/verify-user`

Request body:

```json
{
  "type": "email",
  "value": "user@example.com"
}
```

### Social And Phone Auth Callback Body

Used by `/auth/google/callback`, `/auth/apple/callback`, and
`/auth/phone/callback`.

```json
{
  "idToken": "firebase-id-token",
  "device_type": "android",
  "fcm_token": "firebase-cloud-messaging-token"
}
```

## Settings

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/settings` | Optional | Fetch app, system, payment, and feature settings. |

## Home And Catalogue

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/banners` | Optional | Fetch banners. |
| GET | `/categories` | Optional | Fetch categories or sub-categories. |
| GET | `/categories/sidebar` | Optional | Fetch category filters. |
| GET | `/categories/sub-categories` | Optional | Fetch all-tab sub-categories. |
| GET | `/brands` | Optional | Fetch brands. |
| GET | `/brands/sidebar` | Optional | Fetch brand filters. |
| GET | `/featured-sections` | Optional | Fetch featured sections. |
| GET | `/featured-sections/{sectionIdOrSlug}/products` | Optional | Fetch products for one featured section. |
| GET | `/delivery-zone/products` | Optional | Fetch/search products within a delivery zone. |
| GET | `/products/sidebar-filters` | Optional | Fetch product filter metadata. |

Common query parameters:

| Parameter | Type | Notes |
| --- | --- | --- |
| `latitude` | number | Required by the app for location-aware requests. |
| `longitude` | number | Required by the app for location-aware requests. |
| `page` | integer | Pagination page. |
| `per_page` | integer | Items per page. |
| `scope_category_slug` | string | Limits banners, brands, or featured sections to a category. |
| `categories` | string | Category slug or comma-separated category slugs. |
| `brands` | string | Brand slug or comma-separated brand slugs. |
| `attribute_values` | string | Comma-separated attribute value IDs. |
| `sort` | string | Sort type. The app defaults to relevance. |
| `search` | string | Product search text. |
| `store` | string | Store slug. |
| `include_child_categories` | `0` or `1` | Used for category listings. |
| `home` | boolean | Sent as `true` for home category requests. |

Example product search:

```http
GET /delivery-zone/products?search=chair&per_page=20&page=1&latitude=-6.2&longitude=106.8&sort=relevance
```

## Product Details

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/products/{productSlug}` | Optional | Fetch product detail. |
| GET | `/products/{productSlug}/faqs` | Optional | Fetch product FAQs. |
| GET | `/products/{productSlug}/reviews` | Optional | Fetch product reviews. |
| GET | `/delivery-zone/products` | Optional | Fetch similar products with `exclude_product`. |
| POST | `/reviews` | Yes | Add product review. Multipart. |
| POST | `/reviews/{feedbackId}` | Yes | Update product review. |
| DELETE | `/reviews/{feedbackId}` | Yes | Delete product review. |

Product detail query parameters:

| Parameter | Type |
| --- | --- |
| `latitude` | number |
| `longitude` | number |

Add product review multipart fields:

| Field | Type | Notes |
| --- | --- | --- |
| `order_item_id` | integer | Required. |
| `title` | string | Required. |
| `comment` | string | Required. |
| `rating` | integer | Required. |
| `review_images[]` | file[] | Optional images. |

Update product review body:

```json
{
  "title": "Great product",
  "comment": "Works well",
  "rating": 5
}
```

## Cart

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/user/cart/add` | Yes | Add product variant to cart. |
| GET | `/user/cart` | Yes | Fetch current cart. |
| POST | `/user/cart/item/{cartItemId}` | Yes | Update cart item quantity. |
| DELETE | `/user/cart/item/{cartItemId}` | Yes | Remove cart item. |
| GET | `/user/cart/clear-cart` | Yes | Clear cart. |
| POST | `/user/cart/sync` | Yes | Sync local cart to server. |
| GET | `/user/cart/item/save-for-later` | Yes | Fetch saved-for-later items. |
| POST | `/user/cart/item/save-for-later/{cartItemId}` | Yes | Save a cart item for later. |

### POST `/user/cart/add`

```json
{
  "product_variant_id": 123,
  "store_id": 45,
  "quantity": 2
}
```

### GET `/user/cart`

Query parameters:

| Parameter | Type | Notes |
| --- | --- | --- |
| `address_id` | integer | Optional. |
| `promo_code` | string | Optional. |
| `rush_delivery` | boolean | Optional. |
| `use_wallet` | boolean | Optional. |
| `latitude` | number | Required by the app. |
| `longitude` | number | Required by the app. |

### POST `/user/cart/item/{cartItemId}`

```json
{
  "quantity": 3
}
```

### POST `/user/cart/sync`

```json
{
  "items": [
    {
      "product_variant_id": 123,
      "store_id": 45,
      "quantity": 2
    }
  ]
}
```

## Promo Codes

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/user/promos/available` | Yes | Fetch available promo codes. |
| GET | `/user/promos/validate` | Yes | Validate promo code for cart totals. |

Validate query parameters:

| Parameter | Type |
| --- | --- |
| `promo_code` | string |
| `cart_amount` | number |
| `delivery_charge` | number |

## Addresses And Delivery Zones

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/user/addresses` | Yes | Add address. |
| GET | `/user/addresses` | Yes | Fetch addresses. |
| PUT | `/user/addresses/{addressId}` | Yes | Update address. |
| DELETE | `/user/addresses/{addressId}` | Yes | Delete address. |
| GET | `/delivery-zone/check` | Optional | Check whether coordinates are deliverable. |
| GET | `/delivery-zone` | Optional | List delivery zones. |
| GET | `/delivery-zone/{deliveryZoneId}` | Optional | Fetch delivery zone detail. |

Address request body:

```json
{
  "address_line1": "Street 1",
  "address_line2": "Unit 2",
  "city": "Jakarta",
  "landmark": "Near mall",
  "state": "DKI Jakarta",
  "zipcode": "12345",
  "mobile": "628123456789",
  "address_type": "home",
  "country": "Indonesia",
  "country_code": "ID",
  "latitude": "-6.2",
  "longitude": "106.8"
}
```

Address list query parameters:

| Parameter | Type | Notes |
| --- | --- | --- |
| `zone_id` | integer | Optional delivery zone filter. |

Delivery zone check query parameters:

| Parameter | Type |
| --- | --- |
| `latitude` | number |
| `longitude` | number |

Delivery zone list query parameters:

| Parameter | Type |
| --- | --- |
| `page` | integer |
| `per_page` | integer |
| `search` | string |

## Orders

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/user/orders` | Yes | Create order. Multipart. |
| GET | `/user/orders` | Yes | Fetch user orders. |
| GET | `/user/orders/{orderSlug}` | Yes | Fetch order detail. |
| GET | `/user/orders/{orderSlug}/delivery-boy-location` | Yes | Fetch delivery tracking location. |
| POST | `/user/orders/items/{orderItemId}/return` | Yes | Request item return. Multipart. |
| POST | `/user/orders/items/{orderItemId}/return-cancel` | Yes | Cancel return request. |
| POST | `/user/orders/items/{orderItemId}/cancel` | Yes | Cancel order item. |
| POST | `/user/orders/{orderId}/reorder` | Yes | Re-order a previous order. |

Create order multipart fields:

| Field | Type | Notes |
| --- | --- | --- |
| `payment_type` | string | `cod`, `wallet`, or gateway value such as `stripePayment`. |
| `promo_code` | string | Empty string when unused. |
| `gift_card` | string | Empty string when unused. |
| `address_id` | integer | Required. |
| `rush_delivery` | `0` or `1` | Required. |
| `use_wallet` | `0` or `1` | Required. |
| `order_note` | string | Optional text. |
| `redirect_url` | string | Sent for non-Flutterwave payments. |
| payment detail fields | string | Optional flattened gateway result fields. |
| `attachments[{productId}][]` | file[] | Optional product attachments. |

Order list query parameters:

| Parameter | Type | Notes |
| --- | --- | --- |
| `page` | integer | Required by the app. |
| `per_page` | integer | Required by the app. |
| `date_range` | string | Optional. |
| `status` | string | Optional. |

Return item multipart fields:

| Field | Type | Notes |
| --- | --- | --- |
| `reason` | string | Required. |
| `images[]` | file[] | Optional evidence images. |

## Payments And Wallet

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/razorpay/create-order` | Yes | Create Razorpay order. |
| POST | `/stripe/create-order` | Yes | Create Stripe payment intent. |
| POST | `/paystack/create-order` | Yes | Create Paystack transaction. |
| POST | `/flutterwave/create-order` | Yes | Create Flutterwave order. Route exists, but wallet recharge flow currently uses `/user/wallet/prepare-wallet-recharge`. |
| POST | `/user/wallet/prepare-wallet-recharge` | Yes | Prepare wallet recharge through a payment gateway. |
| GET | `/user/wallet` | Yes | Fetch user wallet balance/details. |
| GET | `/user/wallet/transactions` | Yes | Fetch wallet transactions. |

Razorpay order body:

```json
{
  "amount": 250000,
  "currency": "INR",
  "receipt": "2026-06-16 10:00:00.000"
}
```

Stripe order body:

```json
{
  "amount": 250000,
  "currency": "IDR",
  "additionalData": {}
}
```

Paystack order body:

```json
{
  "amount": 250000
}
```

Prepare wallet recharge body:

```json
{
  "amount": 250000,
  "payment_method": "stripePayment",
  "description": "Wallet top up"
}
```

Wallet transaction query parameters:

| Parameter | Type |
| --- | --- |
| `page` | integer |
| `per_page` | integer |

## Wishlist

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/user/wishlists` | Yes | Fetch user wishlists. |
| POST | `/user/wishlists/create` | Yes | Create wishlist. |
| POST | `/user/wishlists` | Yes | Add item to wishlist. |
| PUT | `/user/wishlists/{wishlistId}` | Yes | Rename wishlist. |
| DELETE | `/user/wishlists/{wishlistId}` | Yes | Delete wishlist. |
| DELETE | `/user/wishlists/items/{itemId}` | Yes | Remove wishlist item. |
| PUT | `/user/wishlists/items/{itemId}/move` | Yes | Move item to another wishlist. |
| GET | `/user/wishlists/{wishlistId}` | Yes | Fetch products in wishlist. |

Create or rename wishlist body:

```json
{
  "title": "Favorites"
}
```

Add item body:

```json
{
  "wishlist_title": "Favorites",
  "product_id": 100,
  "product_variant_id": 123,
  "store_id": 45
}
```

Move item body:

```json
{
  "target_wishlist_id": 2
}
```

Wishlist pagination query parameters:

| Parameter | Type |
| --- | --- |
| `page` | integer |
| `per_page` | integer |
| `latitude` | number |
| `longitude` | number |

## Stores

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/delivery-zone/stores` | Optional | Fetch nearby stores. |
| GET | `/stores/{storeSlug}` | Optional | Fetch store detail. |
| POST | `/stores/map` | Optional | Find stores inside map bounds. |

Nearby stores query parameters:

| Parameter | Type | Notes |
| --- | --- | --- |
| `latitude` | number | Required. |
| `longitude` | number | Required. |
| `page` | integer | Default app value is `1`. |
| `per_page` | integer | Default app value is `15`. |
| `search` | string | Optional. |

Find stores body:

```json
{
  "ne_lat": -6.1,
  "ne_lng": 106.9,
  "sw_lat": -6.3,
  "sw_lng": 106.7,
  "latitude": -6.2,
  "longitude": 106.8
}
```

## Seller Feedback

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/seller-feedback` | Yes | Add seller feedback. |
| POST | `/seller-feedback/{feedbackId}` | Yes | Update seller feedback. |
| DELETE | `/seller-feedback/{feedbackId}` | Yes | Delete seller feedback. |

Add seller feedback body:

```json
{
  "order_item_id": 500,
  "seller_id": 20,
  "title": "Helpful seller",
  "description": "Good service",
  "rating": 5
}
```

Update seller feedback body:

```json
{
  "title": "Updated title",
  "description": "Updated description",
  "rating": 4
}
```

## Delivery Partner Feedback

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/delivery-boy/feedback` | Yes | Add delivery partner feedback. |
| POST | `/delivery-boy/feedback/{feedbackId}` | Yes | Update delivery partner feedback. |
| DELETE | `/delivery-boy/feedback/{feedbackId}` | Yes | Delete delivery partner feedback. |

Add delivery partner feedback body:

```json
{
  "delivery_boy_id": 12,
  "order_id": 200,
  "title": "Fast delivery",
  "description": "Arrived on time",
  "rating": 5
}
```

Update delivery partner feedback body:

```json
{
  "title": "Updated title",
  "description": "Updated description",
  "rating": 4
}
```

## Shopping List And Search Helpers

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/products/search-by-keywords` | Optional | Search products by keyword list. |

Query parameters:

| Parameter | Type |
| --- | --- |
| `latitude` | number |
| `longitude` | number |
| `keywords` | string |
| `per_page` | integer |

The app currently sends `per_page=40` for this endpoint.

## Notifications

| Method | Endpoint | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/user/notifications` | Yes | Fetch notifications. |
| POST | `/user/notifications/{id}/read` | Yes | Mark one notification as read. |
| POST | `/user/notifications/mark-all-read` | Yes | Mark all notifications as read. |

Notification list query parameters:

| Parameter | Type |
| --- | --- |
| `page` | integer |
| `per_page` | integer |

## Policies

The app includes an app policies page, but no dedicated policies endpoint is
called directly from the current client code. Policy content appears to come
from settings or local UI data.
