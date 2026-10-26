
window.onload = function() {
  // Build a system
  var url = window.location.search.match(/url=([^&]+)/);
  if (url && url.length > 1) {
    url = decodeURIComponent(url[1]);
  } else {
    url = window.location.origin;
  }
  var options = {
  "swaggerDoc": {
    "openapi": "3.0.3",
    "info": {
      "title": "Service Backend API",
      "version": "1.0.0",
      "description": "API documentation for users, professionals, admin, content, client projects, chat (REST + Socket.IO at the same server URL), support tickets (customer/professional ↔ admin), and profile/conduct **Reports** (user ↔ professional, admin review)."
    },
    "servers": [
      {
        "url": "http://13.39.19.165:5000",
        "description": "Local server"
      }
    ],
    "tags": [
      {
        "name": "Users"
      },
      {
        "name": "Admin"
      },
      {
        "name": "Professionals"
      },
      {
        "name": "Content"
      },
      {
        "name": "Projects",
        "description": "Client project listings and categories"
      },
      {
        "name": "Professional portfolio",
        "description": "Past work showcase for professionals: portfolio items with multiple photos, optional location and amount. Managed separately from PUT /professionals/complete-profile."
      },
      {
        "name": "Professional availability",
        "description": "Monthly availability calendar for professionals. Days are unavailable by default; an available day may include multiple non-overlapping time shifts."
      },
      {
        "name": "Bookings",
        "description": "Client-to-professional booking flow with requested shifts, optional budget/attachment, and professional acceptance limit of 3 per calendar week (resets Monday 07:00 Europe/Paris)."
      },
      {
        "name": "Search",
        "description": "Find verified professionals by distance from the authenticated user's saved coordinates (PUT /users/location) and optional availability window (Europe/Paris calendar)."
      },
      {
        "name": "Favorites",
        "description": "Saved entities organized in custom lists. Users can favorite professionals; professionals can favorite users and projects."
      },
      {
        "name": "Chat",
        "description": "REST: open conversations and load messages. Real-time: Socket.IO on the **same base URL** (default path `/socket.io/`). Connect with `auth: { token: \"<JWT accessToken>\" }`. Client emits `chat:join` { conversationId }, `chat:message` { conversationId, body }, `chat:leave` { conversationId }; server broadcasts `chat:message` with { id, conversationId, senderRole, body, createdAt }."
      },
      {
        "name": "Support",
        "description": "Contact support between customers or professionals and platform admins. REST: `/users/support/*`, `/professionals/support/*`, `/admin/support/*`. Real-time: same Socket.IO server as chat (`/socket.io/`). Connect with `auth: { token: \"<JWT>\" }` (user, professional, or admin). Emit `support:join` { threadId }, `support:message` { threadId, body }, `support:leave` { threadId }; server broadcasts `support:message` { id, threadId, senderRole, adminId?, body, createdAt } and `support:status` { threadId, status, updatedAt } when a thread is opened/closed via REST."
      },
      {
        "name": "Subscription pricing",
        "description": "**Admin:** `GET`/`PUT /admin/subscription-pricing` — trial days, billing-period lengths in days (annual / standard monthly / reduced monthly), € amounts (all excl. VAT). `reducedPeriodMonths` in responses is derived from reduced billing days (ceil(days/30), max 120). **Public app:** `GET /professionals/subscription-pricing` and `GET /professionals/subscription/catalog` — `pricing` + UI **`catalog`**. **Logged-in pro:** `GET /professionals/me/subscription` — `purchaseOptions`, **`subscription`**, **`stripe`** (customer/sub ids), **`hints`**. **Paid plans (Flutter):** `POST /professionals/subscription/payment-sheet` with `planKey` + `amountEuros` (must match `GET /professionals/me/subscription` pricing) → Payment Sheet secrets; charge uses **server** DB amounts. Env: `STRIPE_SUBSCRIPTION_PRODUCT_ID` (`prod_...`). Webhook `POST /webhooks/stripe`. Trial starts when admin sets **verified** (`promoEligible` only). Re-registration: prior email **or** SIRET → `promoEligible: false` (see `SUBSCRIPTION_PRICING_AND_PROMOS.md`)."
      },
      {
        "name": "Reports",
        "description": "Users report professionals (`POST /users/reports/professionals`); professionals report users (`POST /professionals/reports/users`). Reporters can list their submissions (`GET .../reports`). Admins list, view, and resolve via `GET`/`PATCH /admin/reports/*` (status + optional `solution` text)."
      }
    ],
    "components": {
      "securitySchemes": {
        "bearerAuth": {
          "type": "http",
          "scheme": "bearer",
          "bearerFormat": "JWT"
        }
      },
      "schemas": {
        "ErrorResponse": {
          "type": "object",
          "properties": {
            "success": {
              "type": "boolean",
              "example": false
            },
            "message": {
              "type": "string",
              "example": "Validation failed"
            },
            "errors": {
              "type": "array",
              "nullable": true,
              "items": {
                "type": "object",
                "properties": {
                  "field": {
                    "type": "string",
                    "example": "email"
                  },
                  "message": {
                    "type": "string",
                    "example": "Valid email is required"
                  }
                }
              }
            }
          }
        },
        "User": {
          "type": "object",
          "properties": {
            "id": {
              "type": "integer",
              "example": 1
            },
            "username": {
              "type": "string",
              "example": "John Doe"
            },
            "email": {
              "type": "string",
              "example": "john@example.com"
            },
            "authProvider": {
              "type": "string",
              "example": "local"
            },
            "isEmailVerified": {
              "type": "boolean",
              "example": false
            },
            "status": {
              "type": "string",
              "example": "active"
            },
            "latitude": {
              "type": "number",
              "nullable": true,
              "example": 48.8566
            },
            "longitude": {
              "type": "number",
              "nullable": true,
              "example": 2.3522
            }
          }
        },
        "AdminUser": {
          "type": "object",
          "properties": {
            "id": {
              "type": "integer",
              "example": 1
            },
            "name": {
              "type": "string",
              "example": "Main Admin"
            },
            "email": {
              "type": "string",
              "example": "admin@example.com"
            },
            "status": {
              "type": "string",
              "example": "active"
            }
          }
        },
        "ServiceAreaLocation": {
          "type": "object",
          "description": "Service coverage point. **PUT /professionals/complete-profile** requires coordinates on each item (`latitude`/`longitude`, or aliases `lat`/`lng` or `long` — normalized server-side). From client-side Places/geocoding; this API does not call Google. Optional `label`. Primary business pin: **PUT /professionals/location**.",
          "properties": {
            "latitude": {
              "type": "number",
              "nullable": true,
              "minimum": -90,
              "maximum": 90,
              "example": 48.8566
            },
            "longitude": {
              "type": "number",
              "nullable": true,
              "minimum": -180,
              "maximum": 180,
              "example": 2.3522
            },
            "lat": {
              "type": "number",
              "description": "Alias for `latitude` on write (optional)."
            },
            "lng": {
              "type": "number",
              "description": "Alias for `longitude` on write (optional)."
            },
            "long": {
              "type": "number",
              "description": "Alias for `longitude` on write (optional)."
            },
            "label": {
              "type": "string",
              "maxLength": 200,
              "nullable": true,
              "example": "Lyon — Presqu'île"
            },
            "legacyCityName": {
              "type": "boolean",
              "nullable": true,
              "description": "Present on read only for old DB rows stored as plain city strings"
            }
          }
        },
        "Professional": {
          "type": "object",
          "properties": {
            "id": {
              "type": "integer",
              "example": 1
            },
            "firstName": {
              "type": "string",
              "example": "John"
            },
            "lastName": {
              "type": "string",
              "example": "Doe"
            },
            "email": {
              "type": "string",
              "example": "pro@doeplumbing.com"
            },
            "authProvider": {
              "type": "string",
              "example": "local"
            },
            "isEmailVerified": {
              "type": "boolean",
              "example": true
            },
            "isProfileCompleted": {
              "type": "boolean",
              "example": false
            },
            "promoEligible": {
              "type": "boolean",
              "example": true,
              "description": "False if email or SIRET was already used on a previous professional account (re-registration): no free trial / promotional pricing per policy."
            },
            "verificationStatus": {
              "type": "string",
              "enum": [
                "profile_incomplete",
                "pending_verification",
                "verified",
                "rejected",
                "blocked"
              ],
              "example": "pending_verification"
            },
            "username": {
              "type": "string",
              "example": "john.plumber"
            },
            "phone": {
              "type": "string",
              "example": "+33123456789"
            },
            "address": {
              "type": "string",
              "example": "12 Main Street, Paris, France"
            },
            "description": {
              "type": "string",
              "example": "Experienced home renovation professional."
            },
            "speciality": {
              "type": "string",
              "example": "Bathroom renovation"
            },
            "companyName": {
              "type": "string",
              "example": "Doe Plumbing SARL"
            },
            "contactEmail": {
              "type": "string",
              "example": "contact@doeplumbing.com"
            },
            "companyAddress": {
              "type": "string",
              "example": "10 Rue Example, Paris, France"
            },
            "postalCode": {
              "type": "string",
              "example": "75001"
            },
            "siretNumber": {
              "type": "string",
              "example": "12345678901234"
            },
            "kbisExtractUrl": {
              "type": "string",
              "nullable": true,
              "example": "https://files.example.com/kbis.pdf"
            },
            "certificateUploads": {
              "type": "array",
              "items": {
                "type": "string"
              },
              "example": [
                "https://files.example.com/certificate.pdf"
              ]
            },
            "serviceAreaCities": {
              "type": "array",
              "items": {
                "$ref": "#/components/schemas/ServiceAreaLocation"
              }
            },
            "websiteUrl": {
              "type": "string",
              "nullable": true,
              "example": "https://doeplumbing.com"
            },
            "socialMediaLinks": {
              "type": "array",
              "items": {
                "type": "string"
              },
              "example": [
                "https://instagram.com/doeplumbing"
              ]
            },
            "reviewNotes": {
              "type": "string",
              "nullable": true,
              "example": "Business certificate validated"
            },
            "reviewedAt": {
              "type": "string",
              "format": "date-time",
              "nullable": true
            },
            "reviewedByAdmin": {
              "type": "object",
              "nullable": true,
              "properties": {
                "id": {
                  "type": "integer",
                  "example": 1
                },
                "name": {
                  "type": "string",
                  "example": "Main Admin"
                }
              }
            },
            "latitude": {
              "type": "number",
              "nullable": true,
              "example": 48.8566
            },
            "longitude": {
              "type": "number",
              "nullable": true,
              "example": 2.3522
            },
            "createdAt": {
              "type": "string",
              "format": "date-time"
            },
            "updatedAt": {
              "type": "string",
              "format": "date-time"
            }
          }
        },
        "ContentPage": {
          "type": "object",
          "properties": {
            "id": {
              "type": "integer",
              "example": 1
            },
            "title": {
              "type": "string",
              "example": "Terms and Conditions"
            },
            "slug": {
              "type": "string",
              "example": "terms"
            },
            "content": {
              "type": "string",
              "example": "Add your terms content here."
            },
            "updated_at": {
              "type": "string",
              "format": "date-time"
            }
          }
        },
        "Faq": {
          "type": "object",
          "properties": {
            "id": {
              "type": "integer",
              "example": 1
            },
            "question": {
              "type": "string",
              "example": "How do I create an account?"
            },
            "answer": {
              "type": "string",
              "example": "Use the signup API."
            },
            "display_order": {
              "type": "integer",
              "example": 1
            },
            "is_active": {
              "type": "boolean",
              "example": true
            }
          }
        },
        "ProjectCategory": {
          "type": "object",
          "properties": {
            "id": {
              "type": "integer",
              "example": 1
            },
            "name": {
              "type": "string",
              "example": "Plumbing"
            },
            "slug": {
              "type": "string",
              "example": "plumbing"
            },
            "displayOrder": {
              "type": "integer",
              "example": 1
            }
          }
        },
        "Project": {
          "type": "object",
          "description": "Full project as returned to the owning user or in professional detail",
          "properties": {
            "id": {
              "type": "integer",
              "example": 10
            },
            "title": {
              "type": "string",
              "example": "Building a terrace"
            },
            "description": {
              "type": "string",
              "example": "Looking for a specialist to extend the terrace."
            },
            "categoryId": {
              "type": "integer",
              "example": 1
            },
            "categoryName": {
              "type": "string",
              "example": "Plumbing"
            },
            "categorySlug": {
              "type": "string",
              "example": "plumbing"
            },
            "attachmentUrl": {
              "type": "string",
              "nullable": true,
              "example": "/uploads/projects/1730000000000-abc-doc.pdf"
            },
            "location": {
              "type": "string",
              "example": "Paris, FR"
            },
            "desiredDate": {
              "type": "string",
              "format": "date",
              "example": "2025-06-15"
            },
            "budgetAmount": {
              "type": "string",
              "nullable": true,
              "example": "2500.00"
            },
            "status": {
              "type": "string",
              "enum": [
                "open",
                "closed",
                "cancelled"
              ],
              "example": "open"
            },
            "createdAt": {
              "type": "string",
              "format": "date-time"
            },
            "updatedAt": {
              "type": "string",
              "format": "date-time"
            },
            "client": {
              "type": "object",
              "description": "Present on professional detail responses",
              "properties": {
                "id": {
                  "type": "integer",
                  "example": 3
                },
                "username": {
                  "type": "string",
                  "example": "JaneClient"
                }
              }
            }
          }
        },
        "ProjectFeedItem": {
          "type": "object",
          "description": "Open project row in the verified professional listing",
          "properties": {
            "id": {
              "type": "integer"
            },
            "title": {
              "type": "string"
            },
            "descriptionPreview": {
              "type": "string"
            },
            "categoryId": {
              "type": "integer"
            },
            "categoryName": {
              "type": "string"
            },
            "categorySlug": {
              "type": "string"
            },
            "attachmentUrl": {
              "type": "string",
              "nullable": true
            },
            "location": {
              "type": "string"
            },
            "desiredDate": {
              "type": "string",
              "format": "date"
            },
            "budgetAmount": {
              "type": "string",
              "nullable": true
            },
            "status": {
              "type": "string",
              "example": "open"
            },
            "createdAt": {
              "type": "string",
              "format": "date-time"
            },
            "updatedAt": {
              "type": "string",
              "format": "date-time"
            },
            "client": {
              "type": "object",
              "properties": {
                "id": {
                  "type": "integer"
                },
                "username": {
                  "type": "string"
                }
              }
            }
          }
        },
        "ChatConversation": {
          "type": "object",
          "properties": {
            "id": {
              "type": "integer"
            },
            "userId": {
              "type": "integer"
            },
            "professionalId": {
              "type": "integer"
            },
            "contextProjectId": {
              "type": "integer",
              "nullable": true,
              "description": "Linked project when opened with projectId"
            },
            "updatedAt": {
              "type": "string",
              "format": "date-time"
            },
            "otherParty": {
              "type": "object",
              "additionalProperties": true
            }
          }
        },
        "ChatMessage": {
          "type": "object",
          "properties": {
            "id": {
              "type": "integer"
            },
            "conversationId": {
              "type": "integer"
            },
            "senderRole": {
              "type": "string",
              "enum": [
                "user",
                "professional"
              ]
            },
            "body": {
              "type": "string"
            },
            "createdAt": {
              "type": "string",
              "format": "date-time"
            }
          }
        },
        "SupportThread": {
          "type": "object",
          "properties": {
            "id": {
              "type": "integer"
            },
            "requesterRole": {
              "type": "string",
              "enum": [
                "user",
                "professional"
              ]
            },
            "userId": {
              "type": "integer",
              "nullable": true
            },
            "professionalId": {
              "type": "integer",
              "nullable": true
            },
            "subject": {
              "type": "string",
              "nullable": true
            },
            "status": {
              "type": "string",
              "enum": [
                "open",
                "closed"
              ]
            },
            "createdAt": {
              "type": "string",
              "format": "date-time"
            },
            "updatedAt": {
              "type": "string",
              "format": "date-time"
            }
          }
        },
        "SupportMessage": {
          "type": "object",
          "properties": {
            "id": {
              "type": "integer"
            },
            "threadId": {
              "type": "integer"
            },
            "senderRole": {
              "type": "string",
              "enum": [
                "user",
                "professional",
                "admin"
              ]
            },
            "adminId": {
              "type": "integer",
              "nullable": true,
              "description": "Set when senderRole is admin"
            },
            "body": {
              "type": "string"
            },
            "createdAt": {
              "type": "string",
              "format": "date-time"
            }
          }
        },
        "ReportReason": {
          "type": "string",
          "enum": [
            "hate_speech",
            "nudity_or_sexual_content",
            "threat",
            "harassment",
            "pretending_to_be_something",
            "fraud_or_scam",
            "fake_identity",
            "something_else",
            "other"
          ],
          "example": "harassment"
        },
        "UserReport": {
          "type": "object",
          "description": "Single conduct report; `reporter` / `reported` shapes depend on roles.",
          "properties": {
            "id": {
              "type": "integer"
            },
            "reporterRole": {
              "type": "string",
              "enum": [
                "user",
                "professional"
              ]
            },
            "reporterUserId": {
              "type": "integer",
              "nullable": true
            },
            "reporterProfessionalId": {
              "type": "integer",
              "nullable": true
            },
            "reporter": {
              "type": "object",
              "additionalProperties": true,
              "description": "User reporter: userId, username, email — or professional reporter: professionalId, firstName, lastName, email"
            },
            "reported": {
              "type": "object",
              "additionalProperties": true,
              "description": "Reported professional or user (mirror of public profile fields)"
            },
            "reason": {
              "$ref": "#/components/schemas/ReportReason"
            },
            "details": {
              "type": "string",
              "nullable": true
            },
            "status": {
              "type": "string",
              "enum": [
                "open",
                "reviewed",
                "resolved",
                "dismissed"
              ]
            },
            "adminSolution": {
              "type": "string",
              "nullable": true,
              "description": "Admin resolution / notes shown to reporter"
            },
            "handledByAdminId": {
              "type": "integer",
              "nullable": true
            },
            "handledByAdminName": {
              "type": "string",
              "nullable": true
            },
            "handledAt": {
              "type": "string",
              "format": "date-time",
              "nullable": true
            },
            "createdAt": {
              "type": "string",
              "format": "date-time"
            },
            "updatedAt": {
              "type": "string",
              "format": "date-time"
            }
          }
        },
        "SubscriptionPricing": {
          "type": "object",
          "description": "Raw numbers from `subscription_pricing_settings` (admin-managed).",
          "properties": {
            "trialDays": {
              "type": "integer",
              "example": 45
            },
            "monthlyReducedEuros": {
              "type": "string",
              "example": "99.00"
            },
            "monthlyStandardEuros": {
              "type": "string",
              "example": "140.00"
            },
            "annualEuros": {
              "type": "string",
              "example": "1300.00"
            },
            "annualBillingDays": {
              "type": "integer",
              "example": 365,
              "description": "Length of annual plan period in days (admin)"
            },
            "monthlyStandardBillingDays": {
              "type": "integer",
              "example": 30,
              "description": "Standard monthly plan period in days (admin)"
            },
            "monthlyReducedBillingDays": {
              "type": "integer",
              "example": 180,
              "description": "Reduced-rate monthly window in days (admin)"
            },
            "reducedPeriodMonths": {
              "type": "integer",
              "example": 6,
              "description": "Derived ceil(monthlyReducedBillingDays/30), capped at 120; stored for reporting"
            },
            "updatedAt": {
              "type": "string",
              "format": "date-time",
              "nullable": true
            },
            "updatedByAdminId": {
              "type": "integer",
              "nullable": true
            }
          }
        },
        "SubscriptionCatalogPlan": {
          "type": "object",
          "description": "One tier inside `catalog` (marketing copy + planKey for deep links).",
          "properties": {
            "planKey": {
              "type": "string",
              "enum": [
                "trial",
                "monthly_reduced",
                "monthly_standard",
                "annual"
              ],
              "example": "trial"
            },
            "kind": {
              "type": "string",
              "enum": [
                "trial",
                "subscription"
              ],
              "example": "trial"
            },
            "title": {
              "type": "string",
              "example": "Free trial"
            },
            "shortDescription": {
              "type": "string"
            },
            "priceEuros": {
              "type": "string",
              "example": "0.00"
            },
            "durationDays": {
              "type": "integer",
              "nullable": true,
              "description": "Trial length"
            },
            "durationMonths": {
              "type": "integer",
              "nullable": true,
              "description": "Derived months for reduced tier (legacy display)"
            },
            "billingPeriodDays": {
              "type": "integer",
              "nullable": true,
              "description": "Admin-configured billing period in days (standard monthly / annual)"
            },
            "periodMonths": {
              "type": "integer",
              "nullable": true,
              "description": "Approximate months ceil(billing days/30) for annual"
            }
          }
        },
        "SubscriptionCatalog": {
          "type": "object",
          "properties": {
            "currency": {
              "type": "string",
              "example": "EUR"
            },
            "vatNote": {
              "type": "string",
              "example": "All amounts exclude VAT."
            },
            "trial": {
              "$ref": "#/components/schemas/SubscriptionCatalogPlan"
            },
            "monthlyReduced": {
              "$ref": "#/components/schemas/SubscriptionCatalogPlan"
            },
            "monthlyStandard": {
              "$ref": "#/components/schemas/SubscriptionCatalogPlan"
            },
            "annual": {
              "$ref": "#/components/schemas/SubscriptionCatalogPlan"
            },
            "settingsUpdatedAt": {
              "type": "string",
              "format": "date-time",
              "nullable": true
            }
          }
        },
        "SubscriptionPurchaseOption": {
          "type": "object",
          "properties": {
            "planKey": {
              "type": "string",
              "example": "annual"
            },
            "kind": {
              "type": "string",
              "enum": [
                "trial",
                "month",
                "year"
              ]
            },
            "title": {
              "type": "string"
            },
            "subtitle": {
              "type": "string"
            },
            "priceEuros": {
              "type": "string",
              "example": "1300.00"
            },
            "eligible": {
              "type": "boolean",
              "description": "If false, hide or grey out (e.g. trial for re-registrants; monthly_reduced only while free trial is active)"
            },
            "appliesAfterTrial": {
              "type": "boolean",
              "nullable": true,
              "deprecated": true
            },
            "appliesDuringTrial": {
              "type": "boolean",
              "nullable": true,
              "description": "True for reduced monthly while it depends on trial window"
            },
            "durationDays": {
              "type": "integer",
              "nullable": true
            },
            "periodDays": {
              "type": "integer",
              "nullable": true,
              "description": "Admin-configured period length in days for this tier"
            },
            "periodMonths": {
              "type": "integer",
              "nullable": true,
              "description": "Display months (ceil(periodDays/30) or stored reduced months)"
            }
          }
        },
        "SubscriptionHistoryEntry": {
          "type": "object",
          "description": "Row from professional_subscription_history (Stripe-paid plans).",
          "properties": {
            "id": {
              "type": "integer"
            },
            "planKey": {
              "type": "string"
            },
            "amountEurosExVat": {
              "type": "string"
            },
            "billingInterval": {
              "type": "string",
              "enum": [
                "month",
                "year"
              ]
            },
            "includedMonths": {
              "type": "integer",
              "description": "Months covered (derived from included_days when present)"
            },
            "includedDays": {
              "type": "integer",
              "nullable": true,
              "description": "Admin period in days from Stripe subscription metadata"
            },
            "status": {
              "type": "string",
              "enum": [
                "active",
                "lapsed",
                "canceled"
              ]
            },
            "stripeSubscriptionId": {
              "type": "string"
            },
            "currentPeriodEnd": {
              "type": "string",
              "format": "date-time",
              "nullable": true
            },
            "createdAt": {
              "type": "string",
              "format": "date-time"
            },
            "updatedAt": {
              "type": "string",
              "format": "date-time"
            }
          }
        },
        "SubscriptionCurrentPlanDetail": {
          "type": "object",
          "description": "Active Stripe phase plan + current billing period end (from admin pricing + DB).",
          "properties": {
            "planKey": {
              "type": "string",
              "enum": [
                "annual",
                "monthly_standard",
                "monthly_reduced"
              ]
            },
            "title": {
              "type": "string"
            },
            "priceEurosExVat": {
              "type": "string",
              "description": "Recurring amount excl. VAT from admin settings"
            },
            "billingInterval": {
              "type": "string",
              "enum": [
                "month",
                "year"
              ]
            },
            "periodDays": {
              "type": "integer"
            },
            "currentPeriodEndsAt": {
              "type": "string",
              "format": "date-time",
              "nullable": true
            }
          }
        },
        "SubscriptionUpcomingPlanDetail": {
          "type": "object",
          "description": "Plan queued via Subscription Schedule to start at period end.",
          "properties": {
            "planKey": {
              "type": "string",
              "enum": [
                "annual",
                "monthly_standard",
                "monthly_reduced"
              ]
            },
            "title": {
              "type": "string"
            },
            "priceEurosExVat": {
              "type": "string"
            },
            "billingInterval": {
              "type": "string",
              "enum": [
                "month",
                "year"
              ]
            },
            "periodDays": {
              "type": "integer"
            },
            "startsAt": {
              "type": "string",
              "format": "date-time",
              "nullable": true
            },
            "note": {
              "type": "string"
            }
          }
        },
        "SubscriptionPaymentTransaction": {
          "type": "object",
          "description": "One paid Stripe invoice row (sql/subscription_payment_transactions.sql).",
          "properties": {
            "id": {
              "type": "integer"
            },
            "professionalId": {
              "type": "integer"
            },
            "professionalEmail": {
              "type": "string",
              "nullable": true
            },
            "professionalFirstName": {
              "type": "string",
              "nullable": true
            },
            "professionalLastName": {
              "type": "string",
              "nullable": true
            },
            "stripeInvoiceId": {
              "type": "string"
            },
            "stripePaymentIntentId": {
              "type": "string",
              "nullable": true
            },
            "stripeSubscriptionId": {
              "type": "string"
            },
            "stripeCustomerId": {
              "type": "string",
              "nullable": true
            },
            "amountPaidCents": {
              "type": "integer",
              "description": "Total collected on invoice (Stripe; may include tax depending on account)"
            },
            "currency": {
              "type": "string",
              "example": "EUR"
            },
            "amountEurosExVat": {
              "type": "string",
              "nullable": true,
              "description": "From subscription metadata when available"
            },
            "planKey": {
              "type": "string",
              "nullable": true
            },
            "billingInterval": {
              "type": "string",
              "nullable": true
            },
            "billingReason": {
              "type": "string",
              "nullable": true
            },
            "invoiceStatus": {
              "type": "string",
              "nullable": true
            },
            "hostedInvoiceUrl": {
              "type": "string",
              "nullable": true
            },
            "invoicePdfUrl": {
              "type": "string",
              "nullable": true
            },
            "paidAt": {
              "type": "string",
              "format": "date-time",
              "nullable": true
            },
            "createdAt": {
              "type": "string",
              "format": "date-time"
            }
          }
        },
        "AdminSubscriptionPaymentsApiResponse": {
          "type": "object",
          "properties": {
            "success": {
              "type": "boolean",
              "example": true
            },
            "message": {
              "type": "string"
            },
            "payments": {
              "type": "array",
              "items": {
                "$ref": "#/components/schemas/SubscriptionPaymentTransaction"
              }
            },
            "total": {
              "type": "integer"
            },
            "page": {
              "type": "integer"
            },
            "limit": {
              "type": "integer"
            }
          }
        },
        "ProfessionalSubscriptionPaymentsApiResponse": {
          "type": "object",
          "properties": {
            "success": {
              "type": "boolean",
              "example": true
            },
            "message": {
              "type": "string"
            },
            "payments": {
              "type": "array",
              "items": {
                "$ref": "#/components/schemas/SubscriptionPaymentTransaction"
              }
            }
          }
        },
        "SubscriptionTrialRemaining": {
          "type": "object",
          "nullable": true,
          "properties": {
            "active": {
              "type": "boolean"
            },
            "daysRemaining": {
              "type": "integer",
              "example": 12
            },
            "endsAt": {
              "type": "string",
              "format": "date-time"
            }
          }
        },
        "SubscriptionProfessionalState": {
          "type": "object",
          "properties": {
            "status": {
              "type": "string",
              "enum": [
                "none",
                "trial",
                "active",
                "lapsed"
              ]
            },
            "promoEligible": {
              "type": "boolean"
            },
            "verificationStatus": {
              "type": "string",
              "enum": [
                "profile_incomplete",
                "pending_verification",
                "verified",
                "rejected",
                "blocked"
              ]
            },
            "profileCompleted": {
              "type": "boolean"
            },
            "trialStartedAt": {
              "type": "string",
              "format": "date-time",
              "nullable": true
            },
            "trialEndsAt": {
              "type": "string",
              "format": "date-time",
              "nullable": true
            },
            "trial": {
              "$ref": "#/components/schemas/SubscriptionTrialRemaining"
            },
            "trialStartsAfterVerification": {
              "type": "boolean"
            },
            "canOfferTrial": {
              "type": "boolean"
            },
            "uiSubscriptionState": {
              "type": "string",
              "enum": [
                "none",
                "free_trial",
                "subscribed_billing_pending",
                "subscribed",
                "lapsed"
              ],
              "description": "free_trial = app trial only; subscribed_billing_pending = Stripe trialing, first charge after trial end; subscribed = paid active"
            },
            "subscriptionEntitlementEndsAt": {
              "type": "string",
              "format": "date-time",
              "nullable": true,
              "description": "End of current plan benefit window (free trial end + admin included_days for the purchased tier); requires sql/subscription_entitlement_ends_at.sql"
            },
            "paidBillingStartsAt": {
              "type": "string",
              "format": "date-time",
              "nullable": true,
              "description": "When Stripe billing starts (same as trialEndsAt while uiSubscriptionState is subscribed_billing_pending)"
            },
            "hasCommittedStripeSubscription": {
              "type": "boolean",
              "description": "True if a Stripe subscription exists in trialing/active/past_due (blocks duplicate checkout)"
            },
            "currentPlanKey": {
              "type": "string",
              "enum": [
                "annual",
                "monthly_standard",
                "monthly_reduced"
              ],
              "nullable": true
            },
            "scheduledPlanKey": {
              "type": "string",
              "enum": [
                "annual",
                "monthly_standard",
                "monthly_reduced"
              ],
              "nullable": true
            },
            "scheduledPlanEffectiveAt": {
              "type": "string",
              "format": "date-time",
              "nullable": true
            },
            "currentPlan": {
              "nullable": true,
              "allOf": [
                {
                  "$ref": "#/components/schemas/SubscriptionCurrentPlanDetail"
                }
              ]
            },
            "upcomingPlan": {
              "nullable": true,
              "allOf": [
                {
                  "$ref": "#/components/schemas/SubscriptionUpcomingPlanDetail"
                }
              ]
            }
          }
        },
        "SubscriptionPaywallHints": {
          "type": "object",
          "properties": {
            "showPaywall": {
              "type": "boolean",
              "description": "e.g. verified but no paid plan and trial ended / none"
            },
            "showSubscribeDuringTrial": {
              "type": "boolean",
              "description": "Upsell while trial active"
            },
            "canPurchaseReducedMonthly": {
              "type": "boolean",
              "description": "Same as purchaseOptions monthly_reduced.eligible — only during admin free trial window for promo-eligible accounts"
            }
          }
        },
        "SubscriptionPublicCatalogApiResponse": {
          "type": "object",
          "properties": {
            "success": {
              "type": "boolean",
              "example": true
            },
            "message": {
              "type": "string"
            },
            "pricing": {
              "$ref": "#/components/schemas/SubscriptionPricing"
            },
            "catalog": {
              "$ref": "#/components/schemas/SubscriptionCatalog"
            }
          }
        },
        "SubscriptionStripeSummary": {
          "type": "object",
          "description": "Stripe linkage for Flutter Payment Sheet; updated via webhooks after payment.",
          "properties": {
            "customerId": {
              "type": "string",
              "nullable": true,
              "example": "cus_xxx"
            },
            "subscriptionId": {
              "type": "string",
              "nullable": true,
              "example": "sub_xxx"
            },
            "subscriptionStatus": {
              "type": "string",
              "nullable": true,
              "description": "Last Stripe subscription.status"
            },
            "currentPeriodEnd": {
              "type": "string",
              "format": "date-time",
              "nullable": true
            }
          }
        },
        "SubscriptionPaymentSheetApiResponse": {
          "type": "object",
          "description": "Normally pass `customerId`, `ephemeralKeySecret`, `paymentIntentClientSecret`, and `publishableKey` to Stripe Flutter Payment Sheet. If `queuedPlanChange` is true, no payment is due now — confirm in UI with `effectiveAt` / `pendingPlanKey` and skip Payment Sheet.",
          "properties": {
            "success": {
              "type": "boolean",
              "example": true
            },
            "message": {
              "type": "string"
            },
            "customerId": {
              "type": "string",
              "example": "cus_xxx"
            },
            "ephemeralKeySecret": {
              "type": "string",
              "nullable": true
            },
            "paymentIntentClientSecret": {
              "type": "string",
              "nullable": true
            },
            "subscriptionId": {
              "type": "string",
              "example": "sub_xxx"
            },
            "publishableKey": {
              "type": "string",
              "example": "pk_test_xxx"
            },
            "planKey": {
              "type": "string",
              "enum": [
                "annual",
                "monthly_standard",
                "monthly_reduced"
              ]
            },
            "amountEurosCharged": {
              "type": "string",
              "example": "1300.00",
              "description": "Authoritative ex-VAT amount from admin DB used for Stripe"
            },
            "queuedPlanChange": {
              "type": "boolean",
              "description": "True when a different plan was queued for current period end (Stripe Subscription Schedule)"
            },
            "pendingPlanKey": {
              "type": "string",
              "enum": [
                "annual",
                "monthly_standard",
                "monthly_reduced"
              ],
              "nullable": true
            },
            "effectiveAt": {
              "type": "string",
              "format": "date-time",
              "nullable": true,
              "description": "When the queued plan becomes active"
            }
          }
        },
        "SubscriptionProfessionalMeApiResponse": {
          "type": "object",
          "properties": {
            "success": {
              "type": "boolean",
              "example": true
            },
            "message": {
              "type": "string"
            },
            "pricing": {
              "$ref": "#/components/schemas/SubscriptionPricing"
            },
            "catalog": {
              "$ref": "#/components/schemas/SubscriptionCatalog"
            },
            "purchaseOptions": {
              "type": "array",
              "items": {
                "$ref": "#/components/schemas/SubscriptionPurchaseOption"
              }
            },
            "subscriptionHistory": {
              "type": "array",
              "items": {
                "$ref": "#/components/schemas/SubscriptionHistoryEntry"
              },
              "description": "Paid Stripe subscription records (requires sql/subscription_history_schema.sql)"
            },
            "subscription": {
              "$ref": "#/components/schemas/SubscriptionProfessionalState"
            },
            "hints": {
              "$ref": "#/components/schemas/SubscriptionPaywallHints"
            },
            "stripe": {
              "$ref": "#/components/schemas/SubscriptionStripeSummary"
            }
          }
        },
        "AdminSubscriptionPricingApiResponse": {
          "type": "object",
          "properties": {
            "success": {
              "type": "boolean",
              "example": true
            },
            "message": {
              "type": "string"
            },
            "pricing": {
              "$ref": "#/components/schemas/SubscriptionPricing"
            }
          }
        }
      }
    },
    "paths": {
      "/users/signup": {
        "post": {
          "tags": [
            "Users"
          ],
          "summary": "User signup",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "username",
                    "email",
                    "password"
                  ],
                  "properties": {
                    "username": {
                      "type": "string",
                      "example": "John Doe"
                    },
                    "email": {
                      "type": "string",
                      "example": "john@example.com"
                    },
                    "password": {
                      "type": "string",
                      "example": "Password@123"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "User created"
            },
            "422": {
              "description": "Validation failed"
            }
          }
        }
      },
      "/users/login": {
        "post": {
          "tags": [
            "Users"
          ],
          "summary": "User login",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "email",
                    "password"
                  ],
                  "properties": {
                    "email": {
                      "type": "string",
                      "example": "john@example.com"
                    },
                    "password": {
                      "type": "string",
                      "example": "Password@123"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Login success"
            }
          }
        }
      },
      "/users/social-login": {
        "post": {
          "tags": [
            "Users"
          ],
          "summary": "Google or Apple login",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "provider",
                    "idToken"
                  ],
                  "properties": {
                    "provider": {
                      "type": "string",
                      "enum": [
                        "google",
                        "apple"
                      ]
                    },
                    "idToken": {
                      "type": "string",
                      "example": "provider_id_token"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Social login success"
            }
          }
        }
      },
      "/users/forgot-password": {
        "post": {
          "tags": [
            "Users"
          ],
          "summary": "Send forgot password OTP",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "email"
                  ],
                  "properties": {
                    "email": {
                      "type": "string",
                      "example": "john@example.com"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "OTP handled"
            }
          }
        }
      },
      "/users/verify-reset-otp": {
        "post": {
          "tags": [
            "Users"
          ],
          "summary": "Verify reset OTP",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "email",
                    "otp"
                  ],
                  "properties": {
                    "email": {
                      "type": "string",
                      "example": "john@example.com"
                    },
                    "otp": {
                      "type": "string",
                      "example": "123456"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "OTP verified"
            }
          }
        }
      },
      "/users/reset-password": {
        "post": {
          "tags": [
            "Users"
          ],
          "summary": "Reset user password",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "email",
                    "otp",
                    "password"
                  ],
                  "properties": {
                    "email": {
                      "type": "string",
                      "example": "john@example.com"
                    },
                    "otp": {
                      "type": "string",
                      "example": "123456"
                    },
                    "password": {
                      "type": "string",
                      "example": "NewPassword@123"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Password reset"
            }
          }
        }
      },
      "/users/change-password": {
        "put": {
          "tags": [
            "Users"
          ],
          "summary": "Change password (authenticated, local accounts only)",
          "description": "Requires user JWT. Verifies **currentPassword**, then sets **newPassword** (8–64 characters). Not available for Google/Apple-only accounts.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "currentPassword",
                    "newPassword"
                  ],
                  "properties": {
                    "currentPassword": {
                      "type": "string",
                      "example": "OldPassword@123"
                    },
                    "newPassword": {
                      "type": "string",
                      "example": "NewPassword@123"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Password changed"
            },
            "400": {
              "description": "Social sign-in account"
            },
            "401": {
              "description": "Invalid current password"
            },
            "422": {
              "description": "New password same as current or validation error"
            }
          }
        }
      },
      "/admin/signup": {
        "post": {
          "tags": [
            "Admin"
          ],
          "summary": "Admin signup",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "name",
                    "email",
                    "password"
                  ],
                  "properties": {
                    "name": {
                      "type": "string",
                      "example": "Main Admin"
                    },
                    "email": {
                      "type": "string",
                      "example": "admin@example.com"
                    },
                    "password": {
                      "type": "string",
                      "example": "AdminPass@123"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "Admin created"
            }
          }
        }
      },
      "/admin/login": {
        "post": {
          "tags": [
            "Admin"
          ],
          "summary": "Admin login",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "email",
                    "password"
                  ],
                  "properties": {
                    "email": {
                      "type": "string",
                      "example": "admin@example.com"
                    },
                    "password": {
                      "type": "string",
                      "example": "AdminPass@123"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Admin login success"
            }
          }
        }
      },
      "/admin/subscription-pricing": {
        "get": {
          "tags": [
            "Admin",
            "Subscription pricing"
          ],
          "summary": "Get subscription pricing settings (trial, amounts, billing days per plan)",
          "description": "Returns **`pricing`** only (no `catalog`). Values feed public `GET /professionals/subscription-pricing` and professional `GET /professionals/me/subscription`. Trial length here is used when admin sets a professional to **verified** (promo-eligible accounts).",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "responses": {
            "200": {
              "description": "Current settings",
              "content": {
                "application/json": {
                  "schema": {
                    "$ref": "#/components/schemas/AdminSubscriptionPricingApiResponse"
                  }
                }
              }
            },
            "401": {
              "description": "Unauthorized"
            },
            "403": {
              "description": "Not an admin token"
            }
          }
        },
        "put": {
          "tags": [
            "Admin",
            "Subscription pricing"
          ],
          "summary": "Update subscription pricing (amounts in EUR excl. VAT)",
          "description": "Persists to `subscription_pricing_settings` row `id = 1`; sets `updated_by_admin_id` from JWT.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "trialDays",
                    "annualBillingDays",
                    "monthlyStandardBillingDays",
                    "monthlyReducedBillingDays",
                    "monthlyReducedEuros",
                    "monthlyStandardEuros",
                    "annualEuros"
                  ],
                  "properties": {
                    "trialDays": {
                      "type": "integer",
                      "minimum": 0,
                      "maximum": 365,
                      "example": 45
                    },
                    "annualBillingDays": {
                      "type": "integer",
                      "minimum": 1,
                      "maximum": 1095,
                      "example": 365
                    },
                    "monthlyStandardBillingDays": {
                      "type": "integer",
                      "minimum": 1,
                      "maximum": 120,
                      "example": 30
                    },
                    "monthlyReducedBillingDays": {
                      "type": "integer",
                      "minimum": 1,
                      "maximum": 1095,
                      "example": 180
                    },
                    "monthlyReducedEuros": {
                      "type": "number",
                      "example": 99
                    },
                    "monthlyStandardEuros": {
                      "type": "number",
                      "example": 140
                    },
                    "annualEuros": {
                      "type": "number",
                      "example": 1300
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Updated; response same shape as GET",
              "content": {
                "application/json": {
                  "schema": {
                    "$ref": "#/components/schemas/AdminSubscriptionPricingApiResponse"
                  }
                }
              }
            },
            "401": {
              "description": "Unauthorized"
            },
            "403": {
              "description": "Not an admin token"
            },
            "422": {
              "description": "Validation failed"
            }
          }
        }
      },
      "/admin/subscription-payments": {
        "get": {
          "tags": [
            "Admin",
            "Subscription pricing"
          ],
          "summary": "List Stripe subscription invoice payments (all professionals)",
          "description": "Paginated paid invoices recorded from webhook **`invoice.paid`**. Query: `page`, `limit`, optional `professionalId`, optional `paidFrom` / `paidTo` (ISO or MySQL datetime strings, compared to `paid_at`). Requires **`sql/subscription_payment_transactions.sql`**.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "page",
              "in": "query",
              "schema": {
                "type": "integer",
                "minimum": 1,
                "default": 1
              }
            },
            {
              "name": "limit",
              "in": "query",
              "schema": {
                "type": "integer",
                "minimum": 1,
                "maximum": 100,
                "default": 20
              }
            },
            {
              "name": "professionalId",
              "in": "query",
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            },
            {
              "name": "paidFrom",
              "in": "query",
              "schema": {
                "type": "string"
              },
              "description": "Inclusive lower bound for paid_at"
            },
            {
              "name": "paidTo",
              "in": "query",
              "schema": {
                "type": "string"
              },
              "description": "Inclusive upper bound for paid_at"
            }
          ],
          "responses": {
            "200": {
              "content": {
                "application/json": {
                  "schema": {
                    "$ref": "#/components/schemas/AdminSubscriptionPaymentsApiResponse"
                  }
                }
              }
            },
            "401": {
              "description": "Unauthorized"
            },
            "403": {
              "description": "Not an admin token"
            }
          }
        }
      },
      "/users/professionals/search": {
        "get": {
          "tags": [
            "Search",
            "Users"
          ],
          "summary": "Search verified professionals (from my saved location)",
          "description": "Requires **user** JWT. Search origin is the user's saved `latitude` / `longitude` from **PUT /users/location** (not sent on this request). Query: `radiusKm` (default 50, max 500), optional `availability` (`any`, `today`, `this_week`, `this_month` — Europe/Paris calendar), optional `limit`. Only verified professionals with saved coordinates are returned.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "radiusKm",
              "in": "query",
              "required": false,
              "schema": {
                "type": "number",
                "minimum": 1,
                "maximum": 500,
                "default": 50
              }
            },
            {
              "name": "availability",
              "in": "query",
              "required": false,
              "schema": {
                "type": "string",
                "enum": [
                  "any",
                  "today",
                  "this_week",
                  "this_month"
                ],
                "default": "any"
              }
            },
            {
              "name": "limit",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "minimum": 1,
                "maximum": 100,
                "default": 30
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Matching professionals with distanceKm; response includes origin coordinates used"
            },
            "401": {
              "description": "Missing or invalid token"
            },
            "422": {
              "description": "Invalid query or location not saved"
            }
          }
        }
      },
      "/users/professionals/{professionalId}": {
        "get": {
          "tags": [
            "Users",
            "Professionals"
          ],
          "summary": "Get full public profile of a verified professional",
          "description": "Requires **user** JWT. Returns business/contact fields, optional map coordinates if set, and **portfolio** items with photo URLs. Only **verified** professionals; otherwise 404. Email login and SIRET are not exposed.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "professionalId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Professional + portfolio"
            },
            "401": {
              "description": "Missing or invalid token"
            },
            "404": {
              "description": "Not found or not verified"
            }
          }
        }
      },
      "/professionals/subscription-pricing": {
        "get": {
          "tags": [
            "Professionals",
            "Subscription pricing"
          ],
          "summary": "Public pricing + marketing catalog (for paywall / onboarding)",
          "description": "Returns **pricing** (raw numbers from admin settings) and **catalog** (titles, descriptions, `planKey` for UI). Same JSON as `GET /professionals/subscription/catalog`. **No authentication.** For personalized trial/eligibility use `GET /professionals/me/subscription` with a professional JWT.",
          "responses": {
            "200": {
              "description": "`success`, `message`, `pricing`, `catalog`",
              "content": {
                "application/json": {
                  "schema": {
                    "$ref": "#/components/schemas/SubscriptionPublicCatalogApiResponse"
                  }
                }
              }
            },
            "500": {
              "description": "Pricing row missing / misconfigured"
            }
          }
        }
      },
      "/professionals/subscription/catalog": {
        "get": {
          "tags": [
            "Professionals",
            "Subscription pricing"
          ],
          "summary": "Public subscription catalog (alias of subscription-pricing)",
          "description": "Identical response to `GET /professionals/subscription-pricing`. Prefer one path consistently in mobile/web clients.",
          "responses": {
            "200": {
              "description": "Same as `/professionals/subscription-pricing`",
              "content": {
                "application/json": {
                  "schema": {
                    "$ref": "#/components/schemas/SubscriptionPublicCatalogApiResponse"
                  }
                }
              }
            },
            "500": {
              "description": "Pricing row missing / misconfigured"
            }
          }
        }
      },
      "/professionals/signup": {
        "post": {
          "tags": [
            "Professionals"
          ],
          "summary": "Professional signup with name, email, and password",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "firstName",
                    "lastName",
                    "email",
                    "password"
                  ],
                  "properties": {
                    "firstName": {
                      "type": "string",
                      "example": "John"
                    },
                    "lastName": {
                      "type": "string",
                      "example": "Doe"
                    },
                    "email": {
                      "type": "string",
                      "example": "pro@doeplumbing.com"
                    },
                    "password": {
                      "type": "string",
                      "example": "Password@123"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "Professional account created"
            },
            "409": {
              "description": "Professional email already exists"
            }
          }
        }
      },
      "/professionals/login": {
        "post": {
          "tags": [
            "Professionals"
          ],
          "summary": "Professional login",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "email",
                    "password"
                  ],
                  "properties": {
                    "email": {
                      "type": "string",
                      "example": "pro@doeplumbing.com"
                    },
                    "password": {
                      "type": "string",
                      "example": "Password@123"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Professional login success"
            }
          }
        }
      },
      "/professionals/social-login": {
        "post": {
          "tags": [
            "Professionals"
          ],
          "summary": "Professional Google or Apple login",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "provider",
                    "idToken"
                  ],
                  "properties": {
                    "provider": {
                      "type": "string",
                      "enum": [
                        "google",
                        "apple"
                      ]
                    },
                    "idToken": {
                      "type": "string",
                      "example": "provider_id_token"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Professional social login success"
            }
          }
        }
      },
      "/professionals/forgot-password": {
        "post": {
          "tags": [
            "Professionals"
          ],
          "summary": "Send professional forgot password OTP",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "email"
                  ],
                  "properties": {
                    "email": {
                      "type": "string",
                      "example": "pro@doeplumbing.com"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "OTP handled"
            }
          }
        }
      },
      "/professionals/verify-reset-otp": {
        "post": {
          "tags": [
            "Professionals"
          ],
          "summary": "Verify professional reset OTP",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "email",
                    "otp"
                  ],
                  "properties": {
                    "email": {
                      "type": "string",
                      "example": "pro@doeplumbing.com"
                    },
                    "otp": {
                      "type": "string",
                      "example": "123456"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "OTP verified"
            }
          }
        }
      },
      "/professionals/reset-password": {
        "post": {
          "tags": [
            "Professionals"
          ],
          "summary": "Reset professional password",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "email",
                    "otp",
                    "password"
                  ],
                  "properties": {
                    "email": {
                      "type": "string",
                      "example": "pro@doeplumbing.com"
                    },
                    "otp": {
                      "type": "string",
                      "example": "123456"
                    },
                    "password": {
                      "type": "string",
                      "example": "NewPassword@123"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Password reset"
            }
          }
        }
      },
      "/professionals/me": {
        "get": {
          "tags": [
            "Professionals"
          ],
          "summary": "Get current professional account",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "responses": {
            "200": {
              "description": "Professional account details"
            }
          }
        }
      },
      "/professionals/me/subscription": {
        "get": {
          "tags": [
            "Professionals",
            "Subscription pricing"
          ],
          "summary": "Subscription & trial context for the logged-in professional (paywall)",
          "description": "**Professional JWT required.** Returns **`pricing`** + **`catalog`** (same as public endpoints), **`purchaseOptions`** (ordered list with **`eligible`** — trial/reduced false when `promoEligible` is false), **`subscription`** (`status`, `trialStartedAt`, `trialEndsAt`, `trial.active` / `daysRemaining`, `promoEligible`, `verificationStatus`), **`stripe`** (Stripe customer/subscription ids and status when present), and **`hints`** (`showPaywall`, `showSubscribeDuringTrial`). Requires DB columns from `subscription_professional_state_schema.sql` and `stripe_professional_columns.sql` for Stripe fields. Trial window is opened when admin PATCHes verification to **verified** (only if `promoEligible` and `trialDays` > 0, and trial not already started).",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "responses": {
            "200": {
              "description": "Full paywall payload for the current professional",
              "content": {
                "application/json": {
                  "schema": {
                    "$ref": "#/components/schemas/SubscriptionProfessionalMeApiResponse"
                  }
                }
              }
            },
            "401": {
              "description": "Missing or invalid token"
            },
            "403": {
              "description": "Not a professional token"
            },
            "404": {
              "description": "Professional not found"
            },
            "500": {
              "description": "Pricing not configured"
            }
          }
        }
      },
      "/professionals/me/subscription/payments": {
        "get": {
          "tags": [
            "Professionals",
            "Subscription pricing"
          ],
          "summary": "List my paid subscription invoices (receipts)",
          "description": "Returns rows from **`professional_subscription_payments`** for the JWT professional. Optional `limit` (1–100, default 50). Same source as admin list; requires migration **`sql/subscription_payment_transactions.sql`**.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "limit",
              "in": "query",
              "schema": {
                "type": "integer",
                "minimum": 1,
                "maximum": 100
              }
            }
          ],
          "responses": {
            "200": {
              "content": {
                "application/json": {
                  "schema": {
                    "$ref": "#/components/schemas/ProfessionalSubscriptionPaymentsApiResponse"
                  }
                }
              }
            },
            "401": {
              "description": "Missing or invalid token"
            },
            "403": {
              "description": "Not a professional token"
            }
          }
        }
      },
      "/professionals/subscription/payment-sheet": {
        "post": {
          "tags": [
            "Professionals",
            "Subscription pricing"
          ],
          "summary": "Prepare Stripe Payment Sheet for a paid plan (Flutter — no Checkout URL)",
          "description": "**Professional JWT required.** Send `planKey` plus `amountEuros` (excl. VAT) **exactly** as shown for that plan on `GET /professionals/me/subscription` (`purchaseOptions[].priceEuros` or raw `pricing` fields). Server recomputes the allowed amount from the admin DB; if `amountEuros` does not match (to the cent), the request fails with 422 so the app can refresh pricing. Stripe is charged using the **server** amount only. Env: `STRIPE_SUBSCRIPTION_PRODUCT_ID` + webhook `POST /webhooks/stripe`.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "planKey",
                    "amountEuros"
                  ],
                  "properties": {
                    "planKey": {
                      "type": "string",
                      "enum": [
                        "annual",
                        "monthly_standard",
                        "monthly_reduced"
                      ],
                      "example": "annual"
                    },
                    "amountEuros": {
                      "type": "string",
                      "example": "1300.00",
                      "description": "Must match current server price for planKey (same string/number as catalog)"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Secrets for Payment Sheet",
              "content": {
                "application/json": {
                  "schema": {
                    "$ref": "#/components/schemas/SubscriptionPaymentSheetApiResponse"
                  }
                }
              }
            },
            "403": {
              "description": "Not verified"
            },
            "409": {
              "description": "Already subscribed"
            },
            "422": {
              "description": "Plan not allowed or Stripe request error"
            },
            "503": {
              "description": "Stripe not configured"
            }
          }
        }
      },
      "/professionals/complete-profile": {
        "put": {
          "tags": [
            "Professionals"
          ],
          "summary": "Complete professional business profile and submit for admin verification",
          "description": "**serviceAreaCities** must be an array of coordinate objects (optional `label`). Use `latitude`/`longitude` or `lat`/`lng` (or `long` for longitude). Plain city-name strings are **not** accepted — geocode on the client, then send numbers. Primary map pin: **PUT /professionals/location**.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "username",
                    "phone",
                    "address",
                    "description",
                    "speciality",
                    "companyName",
                    "contactEmail",
                    "companyAddress",
                    "postalCode",
                    "siretNumber",
                    "certificateUploads",
                    "serviceAreaCities"
                  ],
                  "properties": {
                    "username": {
                      "type": "string",
                      "example": "john.plumber"
                    },
                    "phone": {
                      "type": "string",
                      "example": "+33123456789"
                    },
                    "address": {
                      "type": "string",
                      "example": "12 Main Street, Paris, France"
                    },
                    "description": {
                      "type": "string",
                      "example": "Experienced home renovation professional."
                    },
                    "speciality": {
                      "type": "string",
                      "example": "Bathroom renovation"
                    },
                    "companyName": {
                      "type": "string",
                      "example": "Doe Plumbing SARL"
                    },
                    "contactEmail": {
                      "type": "string",
                      "example": "contact@doeplumbing.com"
                    },
                    "companyAddress": {
                      "type": "string",
                      "example": "10 Rue Example, Paris, France"
                    },
                    "postalCode": {
                      "type": "string",
                      "example": "75001"
                    },
                    "siretNumber": {
                      "type": "string",
                      "example": "12345678901234"
                    },
                    "kbisExtractUrl": {
                      "type": "string",
                      "nullable": true,
                      "example": "https://files.example.com/kbis.pdf"
                    },
                    "certificateUploads": {
                      "type": "array",
                      "items": {
                        "type": "string"
                      },
                      "example": [
                        "https://files.example.com/certificate.pdf"
                      ]
                    },
                    "serviceAreaCities": {
                      "type": "array",
                      "minItems": 1,
                      "items": {
                        "$ref": "#/components/schemas/ServiceAreaLocation"
                      },
                      "example": [
                        {
                          "latitude": 48.8566,
                          "longitude": 2.3522,
                          "label": "Paris"
                        },
                        {
                          "latitude": 45.764,
                          "longitude": 4.8357,
                          "label": "Lyon"
                        }
                      ]
                    },
                    "websiteUrl": {
                      "type": "string",
                      "nullable": true,
                      "example": "https://doeplumbing.com"
                    },
                    "socialMediaLinks": {
                      "type": "array",
                      "items": {
                        "type": "string"
                      },
                      "example": [
                        "https://instagram.com/doeplumbing"
                      ]
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Professional profile completed"
            }
          }
        }
      },
      "/professionals/location": {
        "put": {
          "tags": [
            "Professionals"
          ],
          "summary": "Update my coordinates (for search / distance)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "latitude",
                    "longitude"
                  ],
                  "properties": {
                    "latitude": {
                      "type": "number",
                      "minimum": -90,
                      "maximum": 90,
                      "example": 48.8566
                    },
                    "longitude": {
                      "type": "number",
                      "minimum": -180,
                      "maximum": 180,
                      "example": 2.3522
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Location saved"
            }
          }
        }
      },
      "/professionals/change-password": {
        "put": {
          "tags": [
            "Professionals"
          ],
          "summary": "Change password (authenticated, local accounts only)",
          "description": "Requires professional JWT. Verifies **currentPassword**, then sets **newPassword** (8–64 characters). Not available for Google/Apple-only accounts.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "currentPassword",
                    "newPassword"
                  ],
                  "properties": {
                    "currentPassword": {
                      "type": "string",
                      "example": "OldPassword@123"
                    },
                    "newPassword": {
                      "type": "string",
                      "example": "NewPassword@123"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Password changed"
            },
            "400": {
              "description": "Social sign-in account"
            },
            "401": {
              "description": "Invalid current password"
            },
            "422": {
              "description": "New password same as current or validation error"
            }
          }
        }
      },
      "/professionals/portfolio": {
        "get": {
          "tags": [
            "Professional portfolio"
          ],
          "summary": "List my portfolio items (with photos)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "responses": {
            "200": {
              "description": "Portfolio items"
            }
          }
        },
        "post": {
          "tags": [
            "Professional portfolio"
          ],
          "summary": "Create a portfolio item with photos",
          "description": "multipart/form-data: fields title, description, optional completedPlace, optional amount; file field **photos** (repeat for multiple images, JPEG/PNG/WebP). At least one photo required.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "multipart/form-data": {
                "schema": {
                  "type": "object",
                  "required": [
                    "title",
                    "description",
                    "photos"
                  ],
                  "properties": {
                    "title": {
                      "type": "string",
                      "example": "Kitchen renovation"
                    },
                    "description": {
                      "type": "string",
                      "example": "Full remodel with new cabinets."
                    },
                    "completedPlace": {
                      "type": "string",
                      "example": "Lyon, France"
                    },
                    "amount": {
                      "type": "number",
                      "example": 8500
                    },
                    "photos": {
                      "type": "array",
                      "items": {
                        "type": "string",
                        "format": "binary"
                      }
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "Portfolio item created"
            }
          }
        }
      },
      "/professionals/portfolio/{portfolioId}": {
        "get": {
          "tags": [
            "Professional portfolio"
          ],
          "summary": "Get one portfolio item",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "portfolioId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Portfolio item"
            },
            "404": {
              "description": "Not found"
            }
          }
        },
        "put": {
          "tags": [
            "Professional portfolio"
          ],
          "summary": "Update portfolio item metadata (not photos)",
          "description": "JSON body: include at least one of title, description, completedPlace, amount (use null to clear optional fields).",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "portfolioId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "requestBody": {
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "title": {
                      "type": "string"
                    },
                    "description": {
                      "type": "string"
                    },
                    "completedPlace": {
                      "type": "string",
                      "nullable": true
                    },
                    "amount": {
                      "type": "number",
                      "nullable": true
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Updated"
            },
            "404": {
              "description": "Not found"
            }
          }
        },
        "delete": {
          "tags": [
            "Professional portfolio"
          ],
          "summary": "Delete portfolio item and all its photos",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "portfolioId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Deleted"
            },
            "404": {
              "description": "Not found"
            }
          }
        }
      },
      "/professionals/portfolio/{portfolioId}/photos": {
        "post": {
          "tags": [
            "Professional portfolio"
          ],
          "summary": "Add more photos to a portfolio item",
          "description": "multipart/form-data with file field **photos** (repeat). Max 30 photos per item total.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "portfolioId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "multipart/form-data": {
                "schema": {
                  "type": "object",
                  "required": [
                    "photos"
                  ],
                  "properties": {
                    "photos": {
                      "type": "array",
                      "items": {
                        "type": "string",
                        "format": "binary"
                      }
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Item updated with new photos"
            },
            "404": {
              "description": "Item not found"
            }
          }
        }
      },
      "/professionals/portfolio/{portfolioId}/photos/{photoId}": {
        "delete": {
          "tags": [
            "Professional portfolio"
          ],
          "summary": "Remove one photo from a portfolio item",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "portfolioId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            },
            {
              "name": "photoId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Photo removed"
            },
            "404": {
              "description": "Not found"
            }
          }
        }
      },
      "/professionals/availability": {
        "get": {
          "tags": [
            "Professional availability"
          ],
          "summary": "Get my availability for a month",
          "description": "Query param `month` is required (YYYY-MM). Days not explicitly set are returned as unavailable by default.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "month",
              "in": "query",
              "required": true,
              "schema": {
                "type": "string",
                "example": "2026-03"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Availability month"
            }
          }
        }
      },
      "/professionals/availability/{date}": {
        "put": {
          "tags": [
            "Professional availability"
          ],
          "summary": "Set one day's availability (with optional shifts)",
          "description": "JSON body: `isAvailable` boolean. If available, you may pass `shifts` as an array of { startTime, endTime } (HH:MM) and they must not overlap. If isAvailable=false, shifts are cleared.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "date",
              "in": "path",
              "required": true,
              "schema": {
                "type": "string",
                "example": "2026-03-25"
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "isAvailable"
                  ],
                  "properties": {
                    "isAvailable": {
                      "type": "boolean",
                      "example": true
                    },
                    "shifts": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "startTime": {
                            "type": "string",
                            "example": "10:00"
                          },
                          "endTime": {
                            "type": "string",
                            "example": "14:00"
                          }
                        }
                      },
                      "example": [
                        {
                          "startTime": "10:00",
                          "endTime": "14:00"
                        },
                        {
                          "startTime": "16:00",
                          "endTime": "18:00"
                        }
                      ]
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Availability updated"
            }
          }
        }
      },
      "/professionals/bookings": {
        "get": {
          "tags": [
            "Professionals",
            "Bookings"
          ],
          "summary": "List bookings received by current professional",
          "description": "Only verified professionals can access this endpoint.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "status",
              "in": "query",
              "required": false,
              "schema": {
                "type": "string",
                "example": "pending"
              }
            },
            {
              "name": "beforeId",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer"
              }
            },
            {
              "name": "limit",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "minimum": 1,
                "maximum": 50
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Bookings fetched"
            }
          }
        }
      },
      "/professionals/bookings/{bookingId}/status": {
        "put": {
          "tags": [
            "Professionals",
            "Bookings"
          ],
          "summary": "Accept/reject/cancel a booking request",
          "description": "Only verified professionals. Accept action is limited to 3 bookings per calendar week; window resets Monday 07:00 Europe/Paris.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "bookingId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "status"
                  ],
                  "properties": {
                    "status": {
                      "type": "string",
                      "enum": [
                        "accepted",
                        "rejected",
                        "cancelled"
                      ]
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Booking status updated"
            },
            "409": {
              "description": "Already processed or weekly limit reached"
            }
          }
        }
      },
      "/professionals/favorites/lists": {
        "post": {
          "tags": [
            "Professionals",
            "Favorites"
          ],
          "summary": "Create a favorite list (professional)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "name"
                  ],
                  "properties": {
                    "name": {
                      "type": "string",
                      "example": "Recently viewed",
                      "maxLength": 120
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "List created"
            }
          }
        },
        "get": {
          "tags": [
            "Professionals",
            "Favorites"
          ],
          "summary": "List my favorite lists (professional)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "responses": {
            "200": {
              "description": "Lists fetched"
            }
          }
        }
      },
      "/professionals/favorites/items": {
        "post": {
          "tags": [
            "Professionals",
            "Favorites"
          ],
          "summary": "Add favorite item (professional)",
          "description": "For professional role, `targetType` can be `user` or `project`.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "targetType",
                    "targetId"
                  ],
                  "properties": {
                    "targetType": {
                      "type": "string",
                      "enum": [
                        "user",
                        "project"
                      ],
                      "example": "project"
                    },
                    "targetId": {
                      "type": "integer",
                      "example": 25
                    },
                    "listId": {
                      "type": "integer",
                      "nullable": true,
                      "example": 3
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "Favorite added"
            },
            "409": {
              "description": "Already in favorites"
            }
          }
        },
        "get": {
          "tags": [
            "Professionals",
            "Favorites"
          ],
          "summary": "List favorite items (professional)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "listId",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            },
            {
              "name": "targetType",
              "in": "query",
              "required": false,
              "schema": {
                "type": "string",
                "enum": [
                  "user",
                  "project"
                ]
              }
            },
            {
              "name": "beforeId",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            },
            {
              "name": "limit",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "minimum": 1,
                "maximum": 100
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Favorites fetched"
            }
          }
        }
      },
      "/professionals/favorites/items/{itemId}/list": {
        "put": {
          "tags": [
            "Professionals",
            "Favorites"
          ],
          "summary": "Move a favorite item to a list (professional)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "itemId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "requestBody": {
            "required": false,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "listId": {
                      "type": "integer",
                      "nullable": true,
                      "example": 3
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Favorite moved"
            }
          }
        }
      },
      "/professionals/favorites/items/{itemId}": {
        "delete": {
          "tags": [
            "Professionals",
            "Favorites"
          ],
          "summary": "Remove a favorite item (professional)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "itemId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Favorite removed"
            }
          }
        }
      },
      "/admin/users": {
        "get": {
          "tags": [
            "Admin",
            "Users"
          ],
          "summary": "List users for management",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "status",
              "in": "query",
              "required": false,
              "schema": {
                "type": "string",
                "enum": [
                  "active",
                  "inactive",
                  "blocked"
                ]
              }
            },
            {
              "name": "beforeId",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            },
            {
              "name": "limit",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "minimum": 1,
                "maximum": 100,
                "default": 30
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Users fetched"
            }
          }
        }
      },
      "/admin/users/{userId}": {
        "get": {
          "tags": [
            "Admin",
            "Users"
          ],
          "summary": "Get full user details for management",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "userId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "responses": {
            "200": {
              "description": "User details with stats and recent activity"
            },
            "404": {
              "description": "User not found"
            }
          }
        }
      },
      "/admin/users/{userId}/ban": {
        "patch": {
          "tags": [
            "Admin",
            "Users"
          ],
          "summary": "Temporary/permanent ban or unban a user",
          "description": "Use `action` to choose moderation mode. Temporary ban requires `days`. Permanent ban ignores `days`. Unban clears all ban fields and re-activates the account.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "userId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "action"
                  ],
                  "properties": {
                    "action": {
                      "type": "string",
                      "enum": [
                        "temporary",
                        "permanent",
                        "unban"
                      ]
                    },
                    "days": {
                      "type": "integer",
                      "minimum": 1,
                      "maximum": 365,
                      "example": 7
                    },
                    "reason": {
                      "type": "string",
                      "nullable": true,
                      "example": "Spam reports"
                    }
                  }
                },
                "examples": {
                  "temporaryBan": {
                    "summary": "Temporary ban for 7 days",
                    "value": {
                      "action": "temporary",
                      "days": 7,
                      "reason": "Abusive behavior"
                    }
                  },
                  "permanentBan": {
                    "summary": "Permanent ban",
                    "value": {
                      "action": "permanent",
                      "reason": "Repeated severe violations"
                    }
                  },
                  "unban": {
                    "summary": "Unban user",
                    "value": {
                      "action": "unban"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "User moderation state updated"
            },
            "401": {
              "description": "Unauthorized (missing/invalid token)"
            },
            "403": {
              "description": "Forbidden (not admin)"
            },
            "404": {
              "description": "User not found"
            },
            "422": {
              "description": "Invalid payload (e.g. days missing for temporary ban)"
            }
          }
        }
      },
      "/admin/professionals": {
        "get": {
          "tags": [
            "Admin",
            "Professionals"
          ],
          "summary": "List professionals for management",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "verificationStatus",
              "in": "query",
              "required": false,
              "schema": {
                "type": "string",
                "enum": [
                  "profile_incomplete",
                  "pending_verification",
                  "verified",
                  "rejected",
                  "blocked"
                ]
              }
            },
            {
              "name": "beforeId",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            },
            {
              "name": "limit",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "minimum": 1,
                "maximum": 100,
                "default": 30
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Professionals fetched"
            }
          }
        }
      },
      "/admin/professionals/{professionalId}": {
        "get": {
          "tags": [
            "Admin",
            "Professionals"
          ],
          "summary": "Get full professional details for management",
          "description": "Embedded **professional** includes **serviceAreaCities** (array of lat/long points, see **ServiceAreaLocation**), **promoEligible**, **subscriptionStatus**, trial/subscription dates, bans, performance review, etc.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "professionalId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "responses": {
            "200": {
              "description": "**professional** (profile + promo/subscription fields), **stats**, **portfolioItems**, **recentBookings**."
            },
            "404": {
              "description": "Professional not found"
            }
          }
        }
      },
      "/admin/professionals/{professionalId}/verification-status": {
        "patch": {
          "tags": [
            "Admin",
            "Professionals"
          ],
          "summary": "Set professional verification status",
          "description": "Verification workflow: verify, reject, or pending_verification. When set to **verified**, the backend starts a **trial** for **`promoEligible`** professionals (from admin `trialDays`) if not already started. See **Subscription pricing** tag.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "professionalId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "verificationStatus"
                  ],
                  "properties": {
                    "verificationStatus": {
                      "type": "string",
                      "enum": [
                        "verified",
                        "rejected",
                        "pending_verification"
                      ]
                    },
                    "reviewNotes": {
                      "type": "string",
                      "nullable": true,
                      "example": "Need clearer company documents"
                    }
                  }
                },
                "examples": {
                  "verify": {
                    "summary": "Approve professional",
                    "value": {
                      "verificationStatus": "verified",
                      "reviewNotes": "All documents verified"
                    }
                  },
                  "reject": {
                    "summary": "Reject professional",
                    "value": {
                      "verificationStatus": "rejected",
                      "reviewNotes": "Invalid SIRET proof"
                    }
                  },
                  "sendBackToPending": {
                    "summary": "Move back to pending",
                    "value": {
                      "verificationStatus": "pending_verification"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Professional verification updated"
            },
            "401": {
              "description": "Unauthorized (missing/invalid token)"
            },
            "403": {
              "description": "Forbidden (not admin)"
            },
            "404": {
              "description": "Professional not found"
            },
            "422": {
              "description": "Invalid payload"
            }
          }
        }
      },
      "/admin/professionals/{professionalId}/ban": {
        "patch": {
          "tags": [
            "Admin",
            "Professionals"
          ],
          "summary": "Temporary/permanent ban or unban a professional",
          "description": "Ban actions set `verification_status=blocked`. `temporary` requires `days`; `permanent` sets blocked indefinitely; `unban` restores account access.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "professionalId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "action"
                  ],
                  "properties": {
                    "action": {
                      "type": "string",
                      "enum": [
                        "temporary",
                        "permanent",
                        "unban"
                      ]
                    },
                    "days": {
                      "type": "integer",
                      "minimum": 1,
                      "maximum": 365,
                      "example": 7
                    },
                    "reason": {
                      "type": "string",
                      "nullable": true,
                      "example": "Repeated policy violations"
                    }
                  }
                },
                "examples": {
                  "temporaryBan": {
                    "summary": "Temporary 7-day ban",
                    "value": {
                      "action": "temporary",
                      "days": 7,
                      "reason": "Misconduct with clients"
                    }
                  },
                  "permanentBan": {
                    "summary": "Permanent ban",
                    "value": {
                      "action": "permanent",
                      "reason": "Fraudulent documents"
                    }
                  },
                  "unban": {
                    "summary": "Unban professional",
                    "value": {
                      "action": "unban"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Professional moderation state updated"
            },
            "401": {
              "description": "Unauthorized (missing/invalid token)"
            },
            "403": {
              "description": "Forbidden (not admin)"
            },
            "404": {
              "description": "Professional not found"
            },
            "422": {
              "description": "Invalid payload (e.g. days missing for temporary ban)"
            }
          }
        }
      },
      "/admin/professionals/{professionalId}/performance-review": {
        "patch": {
          "tags": [
            "Admin",
            "Professionals"
          ],
          "summary": "Rate professional performance (star rating + internal note)",
          "description": "Stores an internal admin performance review for this professional. Use `starRating` from 1 to 5 and `reviewNote` as internal operational notes.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "professionalId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "starRating",
                    "reviewNote"
                  ],
                  "properties": {
                    "starRating": {
                      "type": "integer",
                      "minimum": 1,
                      "maximum": 5,
                      "example": 4
                    },
                    "reviewNote": {
                      "type": "string",
                      "maxLength": 4000,
                      "example": "Good response time and completion quality. Minor punctuality issue once."
                    }
                  }
                },
                "examples": {
                  "strongPerformance": {
                    "summary": "5-star review",
                    "value": {
                      "starRating": 5,
                      "reviewNote": "Consistently high quality, polite communication, no complaints this month."
                    }
                  },
                  "averagePerformance": {
                    "summary": "3-star review",
                    "value": {
                      "starRating": 3,
                      "reviewNote": "Work quality acceptable but delays observed in two bookings."
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Performance review saved and returned in professional details"
            },
            "401": {
              "description": "Unauthorized (missing/invalid token)"
            },
            "403": {
              "description": "Forbidden (not admin)"
            },
            "404": {
              "description": "Professional not found"
            },
            "422": {
              "description": "Invalid payload (starRating out of range, empty note, etc.)"
            }
          }
        }
      },
      "/admin/project-categories": {
        "get": {
          "tags": [
            "Admin",
            "Projects"
          ],
          "summary": "List all project categories (admin)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "responses": {
            "200": {
              "description": "Project categories fetched"
            }
          }
        },
        "post": {
          "tags": [
            "Admin",
            "Projects"
          ],
          "summary": "Create project category",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "name",
                    "slug"
                  ],
                  "properties": {
                    "name": {
                      "type": "string",
                      "example": "Plastering"
                    },
                    "slug": {
                      "type": "string",
                      "example": "plastering"
                    },
                    "displayOrder": {
                      "type": "integer",
                      "minimum": 0,
                      "example": 7
                    },
                    "isActive": {
                      "type": "boolean",
                      "example": true
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "Project category created"
            },
            "409": {
              "description": "Category slug already exists"
            }
          }
        }
      },
      "/admin/project-categories/{categoryId}": {
        "put": {
          "tags": [
            "Admin",
            "Projects"
          ],
          "summary": "Update project category",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "categoryId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "name": {
                      "type": "string",
                      "example": "Plastering"
                    },
                    "slug": {
                      "type": "string",
                      "example": "plastering"
                    },
                    "displayOrder": {
                      "type": "integer",
                      "minimum": 0,
                      "example": 7
                    },
                    "isActive": {
                      "type": "boolean",
                      "example": true
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Project category updated"
            },
            "404": {
              "description": "Category not found"
            },
            "409": {
              "description": "Category slug already exists"
            }
          }
        },
        "delete": {
          "tags": [
            "Admin",
            "Projects"
          ],
          "summary": "Delete project category",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "categoryId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Project category deleted"
            },
            "404": {
              "description": "Category not found"
            },
            "409": {
              "description": "Category is in use by projects"
            }
          }
        }
      },
      "/content/terms": {
        "get": {
          "tags": [
            "Content"
          ],
          "summary": "Get terms",
          "responses": {
            "200": {
              "description": "Terms page"
            }
          }
        },
        "post": {
          "tags": [
            "Content"
          ],
          "summary": "Create terms",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "title",
                    "content"
                  ],
                  "properties": {
                    "title": {
                      "type": "string",
                      "example": "Terms and Conditions"
                    },
                    "content": {
                      "type": "string",
                      "example": "Your terms content"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Terms saved"
            }
          }
        },
        "put": {
          "tags": [
            "Content"
          ],
          "summary": "Edit terms",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "title",
                    "content"
                  ],
                  "properties": {
                    "title": {
                      "type": "string",
                      "example": "Terms and Conditions"
                    },
                    "content": {
                      "type": "string",
                      "example": "Updated terms content"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Terms updated"
            }
          }
        },
        "delete": {
          "tags": [
            "Content"
          ],
          "summary": "Delete terms",
          "responses": {
            "200": {
              "description": "Terms deleted"
            }
          }
        }
      },
      "/content/privacy": {
        "get": {
          "tags": [
            "Content"
          ],
          "summary": "Get privacy policy",
          "responses": {
            "200": {
              "description": "Privacy page"
            }
          }
        },
        "post": {
          "tags": [
            "Content"
          ],
          "summary": "Create privacy policy",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "title",
                    "content"
                  ],
                  "properties": {
                    "title": {
                      "type": "string",
                      "example": "Privacy Policy"
                    },
                    "content": {
                      "type": "string",
                      "example": "Your privacy policy"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Privacy saved"
            }
          }
        },
        "put": {
          "tags": [
            "Content"
          ],
          "summary": "Edit privacy policy",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "title",
                    "content"
                  ],
                  "properties": {
                    "title": {
                      "type": "string",
                      "example": "Privacy Policy"
                    },
                    "content": {
                      "type": "string",
                      "example": "Updated privacy policy"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Privacy updated"
            }
          }
        },
        "delete": {
          "tags": [
            "Content"
          ],
          "summary": "Delete privacy policy",
          "responses": {
            "200": {
              "description": "Privacy deleted"
            }
          }
        }
      },
      "/content/faqs": {
        "get": {
          "tags": [
            "Content"
          ],
          "summary": "Get FAQs",
          "responses": {
            "200": {
              "description": "FAQ list"
            }
          }
        },
        "post": {
          "tags": [
            "Content"
          ],
          "summary": "Create FAQ",
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "question",
                    "answer"
                  ],
                  "properties": {
                    "question": {
                      "type": "string",
                      "example": "How do I create an account?"
                    },
                    "answer": {
                      "type": "string",
                      "example": "Use the signup API."
                    },
                    "displayOrder": {
                      "type": "integer",
                      "example": 1
                    },
                    "isActive": {
                      "type": "boolean",
                      "example": true
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "FAQ created"
            }
          }
        }
      },
      "/content/faqs/{id}": {
        "put": {
          "tags": [
            "Content"
          ],
          "summary": "Edit FAQ",
          "parameters": [
            {
              "name": "id",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "question",
                    "answer"
                  ],
                  "properties": {
                    "question": {
                      "type": "string",
                      "example": "How do I reset my password?"
                    },
                    "answer": {
                      "type": "string",
                      "example": "Use forgot password and OTP."
                    },
                    "displayOrder": {
                      "type": "integer",
                      "example": 2
                    },
                    "isActive": {
                      "type": "boolean",
                      "example": true
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "FAQ updated"
            }
          }
        },
        "delete": {
          "tags": [
            "Content"
          ],
          "summary": "Delete FAQ",
          "parameters": [
            {
              "name": "id",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "FAQ deleted"
            }
          }
        }
      },
      "/projects/categories": {
        "get": {
          "tags": [
            "Projects"
          ],
          "summary": "List active project categories",
          "description": "Public. Use `categoryId` from this list when creating a project.",
          "responses": {
            "200": {
              "description": "Categories for dropdowns",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean",
                        "example": true
                      },
                      "message": {
                        "type": "string"
                      },
                      "categories": {
                        "type": "array",
                        "items": {
                          "$ref": "#/components/schemas/ProjectCategory"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/users/projects": {
        "post": {
          "tags": [
            "Users",
            "Projects"
          ],
          "summary": "Create a client project (multipart)",
          "description": "Requires user JWT. Send **multipart/form-data**. File field name must be **attachment** (optional). Allowed: PDF, JPEG, PNG, WebP, ZIP.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "multipart/form-data": {
                "schema": {
                  "type": "object",
                  "required": [
                    "title",
                    "description",
                    "categoryId",
                    "location",
                    "desiredDate"
                  ],
                  "properties": {
                    "title": {
                      "type": "string",
                      "example": "Building a terrace"
                    },
                    "description": {
                      "type": "string",
                      "maxLength": 800,
                      "example": "Looking for a specialist for terrace work."
                    },
                    "categoryId": {
                      "type": "integer",
                      "example": 1
                    },
                    "location": {
                      "type": "string",
                      "example": "Paris, FR"
                    },
                    "desiredDate": {
                      "type": "string",
                      "description": "YYYY-MM-DD",
                      "example": "2025-06-15"
                    },
                    "budget": {
                      "type": "number",
                      "nullable": true,
                      "example": 2500
                    },
                    "attachment": {
                      "type": "string",
                      "format": "binary",
                      "description": "Optional file"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "Project created",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "project": {
                        "$ref": "#/components/schemas/Project"
                      }
                    }
                  }
                }
              }
            },
            "400": {
              "description": "Invalid file type or size"
            },
            "422": {
              "description": "Validation failed",
              "content": {
                "application/json": {
                  "schema": {
                    "$ref": "#/components/schemas/ErrorResponse"
                  }
                }
              }
            }
          }
        },
        "get": {
          "tags": [
            "Users",
            "Projects"
          ],
          "summary": "List my projects",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "responses": {
            "200": {
              "description": "Projects owned by the current user",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "projects": {
                        "type": "array",
                        "items": {
                          "$ref": "#/components/schemas/Project"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/users/projects/{projectId}": {
        "put": {
          "tags": [
            "Users",
            "Projects"
          ],
          "summary": "Update my project (multipart)",
          "description": "Requires user JWT. Same **multipart/form-data** fields as `POST /users/projects`. The server must register this route; the mobile app sends `PUT /users/projects/{projectId}`.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "projectId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "string",
                "example": "5"
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "multipart/form-data": {
                "schema": {
                  "type": "object",
                  "required": [
                    "title",
                    "description",
                    "categoryId",
                    "location",
                    "desiredDate"
                  ],
                  "properties": {
                    "title": {
                      "type": "string"
                    },
                    "description": {
                      "type": "string",
                      "maxLength": 800
                    },
                    "categoryId": {
                      "type": "integer"
                    },
                    "location": {
                      "type": "string"
                    },
                    "desiredDate": {
                      "type": "string",
                      "description": "YYYY-MM-DD"
                    },
                    "budget": {
                      "type": "number",
                      "nullable": true
                    },
                    "latitude": {
                      "type": "number",
                      "nullable": true
                    },
                    "longitude": {
                      "type": "number",
                      "nullable": true
                    },
                    "attachment": {
                      "type": "string",
                      "format": "binary",
                      "description": "Optional; replaces previous attachment when provided"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Project updated"
            },
            "400": {
              "description": "Invalid file type or size"
            },
            "404": {
              "description": "Project not found or not owned by the user"
            },
            "422": {
              "description": "Validation failed",
              "content": {
                "application/json": {
                  "schema": {
                    "$ref": "#/components/schemas/ErrorResponse"
                  }
                }
              }
            }
          }
        },
        "delete": {
          "tags": [
            "Users",
            "Projects"
          ],
          "summary": "Delete my project",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "projectId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "string",
                "example": "5"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Project deleted"
            },
            "404": {
              "description": "Project not found"
            }
          }
        }
      },
      "/users/location": {
        "put": {
          "tags": [
            "Users"
          ],
          "summary": "Update my coordinates (for search / distance)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "latitude",
                    "longitude"
                  ],
                  "properties": {
                    "latitude": {
                      "type": "number",
                      "minimum": -90,
                      "maximum": 90,
                      "example": 48.8566
                    },
                    "longitude": {
                      "type": "number",
                      "minimum": -180,
                      "maximum": 180,
                      "example": 2.3522
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Location saved"
            }
          }
        }
      },
      "/users/bookings": {
        "post": {
          "tags": [
            "Users",
            "Bookings"
          ],
          "summary": "Create booking request to a professional",
          "description": "Requires user JWT. Use multipart/form-data when sending attachment. `requestedShifts` may be JSON array or JSON string array.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "professionalId",
                    "bookingDate",
                    "customerLocation",
                    "description",
                    "requestedShifts"
                  ],
                  "properties": {
                    "professionalId": {
                      "type": "integer",
                      "example": 12
                    },
                    "bookingDate": {
                      "type": "string",
                      "example": "2026-03-25"
                    },
                    "customerLocation": {
                      "type": "string",
                      "example": "Paris, FR"
                    },
                    "description": {
                      "type": "string",
                      "example": "Need sink repair and pipe check."
                    },
                    "budget": {
                      "type": "number",
                      "nullable": true,
                      "example": 120
                    },
                    "requestedShifts": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "startTime": {
                            "type": "string",
                            "example": "10:00"
                          },
                          "endTime": {
                            "type": "string",
                            "example": "12:30"
                          }
                        }
                      }
                    }
                  }
                }
              },
              "multipart/form-data": {
                "schema": {
                  "type": "object",
                  "required": [
                    "professionalId",
                    "bookingDate",
                    "customerLocation",
                    "description",
                    "requestedShifts"
                  ],
                  "properties": {
                    "professionalId": {
                      "type": "integer"
                    },
                    "bookingDate": {
                      "type": "string",
                      "example": "2026-03-25"
                    },
                    "customerLocation": {
                      "type": "string"
                    },
                    "description": {
                      "type": "string"
                    },
                    "budget": {
                      "type": "number",
                      "nullable": true
                    },
                    "requestedShifts": {
                      "type": "string",
                      "example": "[{\"startTime\":\"10:00\",\"endTime\":\"12:30\"}]"
                    },
                    "attachment": {
                      "type": "string",
                      "format": "binary"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "Booking created"
            },
            "422": {
              "description": "Validation or availability mismatch"
            }
          }
        },
        "get": {
          "tags": [
            "Users",
            "Bookings"
          ],
          "summary": "List my bookings",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "status",
              "in": "query",
              "required": false,
              "schema": {
                "type": "string",
                "example": "pending"
              }
            },
            {
              "name": "beforeId",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer"
              }
            },
            {
              "name": "limit",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "minimum": 1,
                "maximum": 50
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Bookings fetched"
            }
          }
        }
      },
      "/users/bookings/professionals/{professionalId}/availability": {
        "get": {
          "tags": [
            "Users",
            "Bookings"
          ],
          "summary": "Get a professional availability month for booking UI",
          "description": "Use this to render selectable days/time slots before creating booking. Returns all month days; non-configured days are unavailable by default.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "professionalId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            },
            {
              "name": "month",
              "in": "query",
              "required": true,
              "schema": {
                "type": "string",
                "example": "2026-03"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Availability month for selected professional"
            }
          }
        }
      },
      "/users/favorites/lists": {
        "post": {
          "tags": [
            "Users",
            "Favorites"
          ],
          "summary": "Create a favorite list (user)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "name"
                  ],
                  "properties": {
                    "name": {
                      "type": "string",
                      "example": "Save to favorites",
                      "maxLength": 120
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "List created"
            }
          }
        },
        "get": {
          "tags": [
            "Users",
            "Favorites"
          ],
          "summary": "List my favorite lists (user)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "responses": {
            "200": {
              "description": "Lists fetched"
            }
          }
        }
      },
      "/users/favorites/lists/{listId}": {
        "put": {
          "tags": [
            "Users",
            "Favorites"
          ],
          "summary": "Rename a favorite list (user)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "listId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "name"
                  ],
                  "properties": {
                    "name": {
                      "type": "string",
                      "maxLength": 120,
                      "example": "My homes"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "List renamed"
            },
            "404": {
              "description": "List not found"
            }
          }
        },
        "patch": {
          "tags": [
            "Users",
            "Favorites"
          ],
          "summary": "Rename a favorite list (user) — alternate to PUT",
          "description": "Mobile clients try PATCH if PUT is not registered.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "listId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "name"
                  ],
                  "properties": {
                    "name": {
                      "type": "string",
                      "maxLength": 120
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "List renamed"
            }
          }
        },
        "delete": {
          "tags": [
            "Users",
            "Favorites"
          ],
          "summary": "Delete a favorite list (user)",
          "description": "Deletes only the list container. Favorited items remain saved and become uncategorized.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "listId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "responses": {
            "200": {
              "description": "List deleted"
            },
            "404": {
              "description": "List not found"
            }
          }
        }
      },
      "/users/favorites/items": {
        "post": {
          "tags": [
            "Users",
            "Favorites"
          ],
          "summary": "Add a professional to favorites",
          "description": "For user role, only `targetType=professional` is accepted.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "targetType",
                    "targetId"
                  ],
                  "properties": {
                    "targetType": {
                      "type": "string",
                      "enum": [
                        "professional"
                      ],
                      "example": "professional"
                    },
                    "targetId": {
                      "type": "integer",
                      "example": 1
                    },
                    "listId": {
                      "type": "integer",
                      "nullable": true,
                      "example": 10
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "Favorite added"
            },
            "409": {
              "description": "Already in favorites"
            }
          }
        },
        "get": {
          "tags": [
            "Users",
            "Favorites"
          ],
          "summary": "List favorite items (user)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "listId",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            },
            {
              "name": "targetType",
              "in": "query",
              "required": false,
              "schema": {
                "type": "string",
                "enum": [
                  "professional"
                ]
              }
            },
            {
              "name": "beforeId",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            },
            {
              "name": "limit",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "minimum": 1,
                "maximum": 100
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Favorites fetched"
            }
          }
        }
      },
      "/users/favorites/items/{itemId}/list": {
        "put": {
          "tags": [
            "Users",
            "Favorites"
          ],
          "summary": "Move a favorite item to a list (user)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "itemId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "requestBody": {
            "required": false,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "listId": {
                      "type": "integer",
                      "nullable": true,
                      "example": 10
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Favorite moved"
            }
          }
        }
      },
      "/users/favorites/items/{itemId}": {
        "delete": {
          "tags": [
            "Users",
            "Favorites"
          ],
          "summary": "Remove a favorite item (user)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "itemId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Favorite removed"
            }
          }
        }
      },
      "/professionals/projects": {
        "get": {
          "tags": [
            "Professionals",
            "Projects"
          ],
          "summary": "List open projects (verified professionals only)",
          "description": "Requires professional JWT and **verification_status = verified**.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "limit",
              "in": "query",
              "schema": {
                "type": "integer",
                "minimum": 1,
                "maximum": 50,
                "default": 20
              }
            },
            {
              "name": "beforeId",
              "in": "query",
              "description": "Pagination: only return projects with id less than this value",
              "schema": {
                "type": "integer"
              }
            },
            {
              "name": "categoryId",
              "in": "query",
              "schema": {
                "type": "integer"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Feed of open projects",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "projects": {
                        "type": "array",
                        "items": {
                          "$ref": "#/components/schemas/ProjectFeedItem"
                        }
                      }
                    }
                  }
                }
              }
            },
            "403": {
              "description": "Professional not verified"
            }
          }
        }
      },
      "/professionals/projects/{projectId}": {
        "get": {
          "tags": [
            "Professionals",
            "Projects"
          ],
          "summary": "Get one open project (detail + client summary for chat)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "projectId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Project detail",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "project": {
                        "$ref": "#/components/schemas/Project"
                      }
                    }
                  }
                }
              }
            },
            "403": {
              "description": "Professional not verified"
            },
            "404": {
              "description": "Not found or not open"
            }
          }
        }
      },
      "/users/chat/conversations": {
        "post": {
          "tags": [
            "Users",
            "Chat"
          ],
          "summary": "Open or create a conversation with a professional",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "professionalId"
                  ],
                  "properties": {
                    "professionalId": {
                      "type": "integer",
                      "example": 1
                    },
                    "projectId": {
                      "type": "integer",
                      "nullable": true,
                      "description": "Optional; must be a project you own",
                      "example": 10
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Conversation ready",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "conversation": {
                        "$ref": "#/components/schemas/ChatConversation"
                      }
                    }
                  }
                }
              }
            },
            "422": {
              "description": "Validation failed"
            }
          }
        },
        "get": {
          "tags": [
            "Users",
            "Chat"
          ],
          "summary": "List all conversations for the user",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "responses": {
            "200": {
              "description": "List of conversations",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "conversations": {
                        "type": "array",
                        "items": {
                          "$ref": "#/components/schemas/ChatConversation"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/users/chat/conversations/{conversationId}/messages": {
        "get": {
          "tags": [
            "Users",
            "Chat"
          ],
          "summary": "List messages in a conversation as a user",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "conversationId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            },
            {
              "name": "limit",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "default": 50
              }
            },
            {
              "name": "beforeId",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Messages oldest-first in the returned window",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "messages": {
                        "type": "array",
                        "items": {
                          "$ref": "#/components/schemas/ChatMessage"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/professionals/chat/conversations": {
        "post": {
          "tags": [
            "Professionals",
            "Chat"
          ],
          "summary": "Open or create a conversation with a client (user)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "userId"
                  ],
                  "properties": {
                    "userId": {
                      "type": "integer",
                      "example": 3,
                      "description": "Client user id (e.g. from project detail)"
                    },
                    "projectId": {
                      "type": "integer",
                      "nullable": true,
                      "description": "Optional open project id; must belong to userId",
                      "example": 10
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Conversation ready",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "conversation": {
                        "$ref": "#/components/schemas/ChatConversation"
                      }
                    }
                  }
                }
              }
            },
            "422": {
              "description": "Validation failed"
            }
          }
        },
        "get": {
          "tags": [
            "Professionals",
            "Chat"
          ],
          "summary": "List all conversations for the professional",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "responses": {
            "200": {
              "description": "List of conversations",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "conversations": {
                        "type": "array",
                        "items": {
                          "$ref": "#/components/schemas/ChatConversation"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/professionals/chat/conversations/{conversationId}/messages": {
        "get": {
          "tags": [
            "Professionals",
            "Chat"
          ],
          "summary": "List messages in a conversation as a professional",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "conversationId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            },
            {
              "name": "limit",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer",
                "default": 50
              }
            },
            {
              "name": "beforeId",
              "in": "query",
              "required": false,
              "schema": {
                "type": "integer"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Messages oldest-first in the returned window",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "messages": {
                        "type": "array",
                        "items": {
                          "$ref": "#/components/schemas/ChatMessage"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/users/support/threads": {
        "post": {
          "tags": [
            "Users",
            "Support"
          ],
          "summary": "Create a support thread (customer → admin)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "body"
                  ],
                  "properties": {
                    "subject": {
                      "type": "string",
                      "maxLength": 255,
                      "nullable": true
                    },
                    "body": {
                      "type": "string",
                      "description": "First message (required)"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "Thread created",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "thread": {
                        "$ref": "#/components/schemas/SupportThread"
                      },
                      "firstMessage": {
                        "$ref": "#/components/schemas/SupportMessage"
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "get": {
          "tags": [
            "Users",
            "Support"
          ],
          "summary": "List support threads for the authenticated customer",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "responses": {
            "200": {
              "description": "Threads for this user",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "threads": {
                        "type": "array",
                        "items": {
                          "$ref": "#/components/schemas/SupportThread"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/users/support/threads/{threadId}/messages": {
        "get": {
          "tags": [
            "Users",
            "Support"
          ],
          "summary": "List messages in a support thread (customer)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "threadId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            },
            {
              "name": "limit",
              "in": "query",
              "schema": {
                "type": "integer",
                "default": 50
              }
            },
            {
              "name": "beforeId",
              "in": "query",
              "schema": {
                "type": "integer"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Messages oldest-first in the returned window",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "messages": {
                        "type": "array",
                        "items": {
                          "$ref": "#/components/schemas/SupportMessage"
                        }
                      }
                    }
                  }
                }
              }
            },
            "403": {
              "description": "Not your thread"
            },
            "404": {
              "description": "Thread not found"
            }
          }
        },
        "post": {
          "tags": [
            "Users",
            "Support"
          ],
          "summary": "Send a message in an open support thread (customer)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "threadId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "body"
                  ],
                  "properties": {
                    "body": {
                      "type": "string"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Message stored"
            },
            "422": {
              "description": "Thread closed or empty body"
            }
          }
        }
      },
      "/professionals/support/threads": {
        "post": {
          "tags": [
            "Professionals",
            "Support"
          ],
          "summary": "Create a support thread (professional → admin)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "body"
                  ],
                  "properties": {
                    "subject": {
                      "type": "string",
                      "maxLength": 255,
                      "nullable": true
                    },
                    "body": {
                      "type": "string"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "Thread created"
            }
          }
        },
        "get": {
          "tags": [
            "Professionals",
            "Support"
          ],
          "summary": "List support threads for the authenticated professional",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "responses": {
            "200": {
              "description": "Threads"
            }
          }
        }
      },
      "/professionals/support/threads/{threadId}/messages": {
        "get": {
          "tags": [
            "Professionals",
            "Support"
          ],
          "summary": "List messages in a support thread (professional)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "threadId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            },
            {
              "name": "limit",
              "in": "query",
              "schema": {
                "type": "integer"
              }
            },
            {
              "name": "beforeId",
              "in": "query",
              "schema": {
                "type": "integer"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Messages"
            }
          }
        },
        "post": {
          "tags": [
            "Professionals",
            "Support"
          ],
          "summary": "Send a message in an open support thread (professional)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "threadId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "body"
                  ],
                  "properties": {
                    "body": {
                      "type": "string"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Message stored"
            }
          }
        }
      },
      "/admin/support/threads": {
        "get": {
          "tags": [
            "Admin",
            "Support"
          ],
          "summary": "List all support threads",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "status",
              "in": "query",
              "schema": {
                "type": "string",
                "enum": [
                  "open",
                  "closed"
                ]
              }
            },
            {
              "name": "requesterRole",
              "in": "query",
              "schema": {
                "type": "string",
                "enum": [
                  "user",
                  "professional"
                ]
              }
            },
            {
              "name": "limit",
              "in": "query",
              "schema": {
                "type": "integer",
                "default": 50
              }
            },
            {
              "name": "offset",
              "in": "query",
              "schema": {
                "type": "integer",
                "default": 0
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Threads",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "threads": {
                        "type": "array",
                        "items": {
                          "$ref": "#/components/schemas/SupportThread"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/admin/support/threads/{threadId}": {
        "get": {
          "tags": [
            "Admin",
            "Support"
          ],
          "summary": "Get one support thread",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "threadId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Thread"
            },
            "404": {
              "description": "Not found"
            }
          }
        }
      },
      "/admin/support/threads/{threadId}/messages": {
        "get": {
          "tags": [
            "Admin",
            "Support"
          ],
          "summary": "List messages in a thread",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "threadId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            },
            {
              "name": "limit",
              "in": "query",
              "schema": {
                "type": "integer"
              }
            },
            {
              "name": "beforeId",
              "in": "query",
              "schema": {
                "type": "integer"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Messages"
            }
          }
        },
        "post": {
          "tags": [
            "Admin",
            "Support"
          ],
          "summary": "Reply as admin",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "threadId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "body"
                  ],
                  "properties": {
                    "body": {
                      "type": "string"
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Message stored"
            }
          }
        }
      },
      "/admin/support/threads/{threadId}/status": {
        "patch": {
          "tags": [
            "Admin",
            "Support"
          ],
          "summary": "Set thread open or closed",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "threadId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "status"
                  ],
                  "properties": {
                    "status": {
                      "type": "string",
                      "enum": [
                        "open",
                        "closed"
                      ]
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Updated"
            }
          }
        }
      },
      "/users/reports/professionals": {
        "post": {
          "tags": [
            "Users",
            "Reports"
          ],
          "summary": "Report a professional",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "professionalId",
                    "reason"
                  ],
                  "properties": {
                    "professionalId": {
                      "type": "integer",
                      "minimum": 1
                    },
                    "reason": {
                      "$ref": "#/components/schemas/ReportReason"
                    },
                    "details": {
                      "type": "string",
                      "maxLength": 2000,
                      "nullable": true
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "Report created",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "report": {
                        "$ref": "#/components/schemas/UserReport"
                      }
                    }
                  }
                }
              }
            },
            "404": {
              "description": "Professional not found"
            }
          }
        }
      },
      "/users/reports": {
        "get": {
          "tags": [
            "Users",
            "Reports"
          ],
          "summary": "List reports filed by the authenticated user",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "responses": {
            "200": {
              "description": "Reports for this user as reporter (newest first)",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "reports": {
                        "type": "array",
                        "items": {
                          "$ref": "#/components/schemas/UserReport"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/professionals/reports/users": {
        "post": {
          "tags": [
            "Professionals",
            "Reports"
          ],
          "summary": "Report a user (customer)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "userId",
                    "reason"
                  ],
                  "properties": {
                    "userId": {
                      "type": "integer",
                      "minimum": 1
                    },
                    "reason": {
                      "$ref": "#/components/schemas/ReportReason"
                    },
                    "details": {
                      "type": "string",
                      "maxLength": 2000,
                      "nullable": true
                    }
                  }
                }
              }
            }
          },
          "responses": {
            "201": {
              "description": "Report created",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "report": {
                        "$ref": "#/components/schemas/UserReport"
                      }
                    }
                  }
                }
              }
            },
            "404": {
              "description": "User not found"
            }
          }
        }
      },
      "/professionals/reports": {
        "get": {
          "tags": [
            "Professionals",
            "Reports"
          ],
          "summary": "List reports filed by the authenticated professional",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "responses": {
            "200": {
              "description": "Reports for this professional as reporter",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "reports": {
                        "type": "array",
                        "items": {
                          "$ref": "#/components/schemas/UserReport"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/admin/reports": {
        "get": {
          "tags": [
            "Admin",
            "Reports"
          ],
          "summary": "List all reports (filter by status / reporter role)",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "status",
              "in": "query",
              "schema": {
                "type": "string",
                "enum": [
                  "open",
                  "reviewed",
                  "resolved",
                  "dismissed"
                ]
              }
            },
            {
              "name": "reporterRole",
              "in": "query",
              "schema": {
                "type": "string",
                "enum": [
                  "user",
                  "professional"
                ]
              }
            },
            {
              "name": "limit",
              "in": "query",
              "schema": {
                "type": "integer",
                "default": 50,
                "minimum": 1,
                "maximum": 100
              }
            },
            {
              "name": "offset",
              "in": "query",
              "schema": {
                "type": "integer",
                "default": 0,
                "minimum": 0
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Reports",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "reports": {
                        "type": "array",
                        "items": {
                          "$ref": "#/components/schemas/UserReport"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/admin/reports/{reportId}": {
        "get": {
          "tags": [
            "Admin",
            "Reports"
          ],
          "summary": "Get one report",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "reportId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            }
          ],
          "responses": {
            "200": {
              "description": "Report",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "report": {
                        "$ref": "#/components/schemas/UserReport"
                      }
                    }
                  }
                }
              }
            },
            "404": {
              "description": "Not found"
            }
          }
        },
        "patch": {
          "tags": [
            "Admin",
            "Reports"
          ],
          "summary": "Update status and/or admin solution",
          "description": "Send at least one of `status` or `solution`. Sets `handledByAdminId` and `handledAt` when applied. Empty `solution` clears stored text.",
          "security": [
            {
              "bearerAuth": []
            }
          ],
          "parameters": [
            {
              "name": "reportId",
              "in": "path",
              "required": true,
              "schema": {
                "type": "integer"
              }
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "string",
                      "enum": [
                        "open",
                        "reviewed",
                        "resolved",
                        "dismissed"
                      ]
                    },
                    "solution": {
                      "type": "string",
                      "maxLength": 8000,
                      "description": "Stored as adminSolution"
                    }
                  },
                  "description": "At least one of status or solution required"
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Updated",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "success": {
                        "type": "boolean"
                      },
                      "message": {
                        "type": "string"
                      },
                      "report": {
                        "$ref": "#/components/schemas/UserReport"
                      }
                    }
                  }
                }
              }
            },
            "404": {
              "description": "Not found"
            }
          }
        }
      }
    }
  },
  "customOptions": {}
};
  url = options.swaggerUrl || url
  var urls = options.swaggerUrls
  var customOptions = options.customOptions
  var spec1 = options.swaggerDoc
  var swaggerOptions = {
    spec: spec1,
    url: url,
    urls: urls,
    dom_id: '#swagger-ui',
    deepLinking: true,
    presets: [
      SwaggerUIBundle.presets.apis,
      SwaggerUIStandalonePreset
    ],
    plugins: [
      SwaggerUIBundle.plugins.DownloadUrl
    ],
    layout: "StandaloneLayout"
  }
  for (var attrname in customOptions) {
    swaggerOptions[attrname] = customOptions[attrname];
  }
  var ui = SwaggerUIBundle(swaggerOptions)

  if (customOptions.oauth) {
    ui.initOAuth(customOptions.oauth)
  }

  if (customOptions.preauthorizeApiKey) {
    const key = customOptions.preauthorizeApiKey.authDefinitionKey;
    const value = customOptions.preauthorizeApiKey.apiKeyValue;
    if (!!key && !!value) {
      const pid = setInterval(() => {
        const authorized = ui.preauthorizeApiKey(key, value);
        if(!!authorized) clearInterval(pid);
      }, 500)

    }
  }

  if (customOptions.authAction) {
    ui.authActions.authorize(customOptions.authAction)
  }

  window.ui = ui
}
