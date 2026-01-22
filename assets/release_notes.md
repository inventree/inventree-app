### x.xx.x - Month Year
---

- Support display of custom status codes
- Fix default values for list sorting


### 0.21.2 - January 2026
---

- Fixes bug which launched camera twice when uploading an attachment
- Fixed bug related to list sorting and filtering

### 0.21.1 - November 2025
---

- Fixed app freeze bug after form submission

### 0.21.0 - November 2025
---

- Support label printing again, fixing issues with new printing API
- Adds zoom controller for barcode scanner camera view
- Display default stock location in Part detail page
- Display stock information in SupplierPart detail page

### 0.20.2 - November 2025
---

- Fixes URL for reporting issues on GitHub
- Fix for uploading files against server with self-signed certificates

### 0.20.1 - October 2025
---

- Bug fix for camera barcode scanner

### 0.20.0 - October 2025
---

- View pending shipments from the home screen
- Display detail view for shipments
- Adds ability to ship pending outgoing shipments
- Adds ability to mark outgoing shipments as "checked" or "unchecked"
- Updated translations

### 0.19.3 - September 2025
---

- Fixes incorrect priority of barcode scanner results

### 0.19.2 - August 2025
---

- Allow purchase orders to be completed
- Improved UX across the entire app
- Fix bug which prevented display of part images for purchase order line items

### 0.19.1 - July 2025
---
- Fixes bug related to barcode scanning with certain devices

### 0.19.0 - June 2025
---
- Replace barcode scanning library for better performance
- Display part pricing information
- Updated theme support
- Fix broken documentation link
- Reduce frequency of notification checks
- Updated translations
- Add image cropping functionality

### 0.18.1 - April 2025
---
- Fix bug associated with handling invalid URLs

### 0.18.0 - April 2025
---
- Adds ability to create new companies from the app
- Allow creation of line items against pending sales orders
- Support "extra line items" for purchase orders
- Support "extra line items" for sales orders
- Display start date for purchase orders
- Display start date for sales orders
- Fix scrolling behaviour for some widgets
- Updated search functionality
- Updated translations

### 0.17.4 - January 2025
---
- Display responsible owner for orders
- Display completion date for orders
- Updated translations

### 0.17.3 - January 2025
---

- Fixes bug which prevent dialog boxes from being dismissed correctly
- Enable editing of attachment comments
- Updated translations

### 0.17.2 - December 2024
---

- Fixed error message when printing a label to a remote machine
- Prevent notification sounds from pause media playback
- Display stock expiry information
- Updated translations

### 0.17.1 - December 2024
---

- Add support for ManufacturerPart model
- Support barcode scanning for ManufacturerPart
- Fix bugs in global search view
- Fixes barcode scanning bug which prevents scanning of DataMatrix codes
- Display "destination" information in PurchaseOrder detail view
- Pre-fill "location" field when receiving items against PurchaseOrder
- Fix display of part name in PurchaseOrderLineItem list
- Adds "assigned to me" filter for Purchase Order list
- Adds "assigned to me" filter for Sales Order list
- Updated translations

### 0.17.0 - December 2024
---

- Improved barcode scanning with new scanning library
- Prevent screen turning off when scanning barcodes
- Improved support for Stock Item test results
- Enhanced home-screen display using grid-view
- Improvements for image uploading
- Provide "upload image" shortcut on Purchase Order detail view
- Provide "upload image" shortcut on Sales Order detail view
- Clearly indicate if a StockItem is unavailable
- Improved list filtering management
- Updated translations

### 0.16.5 - September 2024
---

- Allow blank values to be entered into numerical fields
- Updated translations

### 0.16.4 - September 2024
---

- Fixes bug related to printing stock item labels

### 0.16.3 - August 2024
---

- Fixes bug relating to viewing attachment files
- Fixes bug relating to uploading attachment files


### 0.16.2 - August 2024
---

- Support "ON_HOLD" status for Purchase Orders
- Support "ON_HOLD" status for Sales Orders
- Change base icon package from FontAwesome to TablerIcons
- Bug fixes for barcode scanning
- Translation updates

### 0.16.1 - July 2024
---

- Update base packages for Android

### 0.16.0 - June 2024
---

- Add support for new file attachments API
- Drop support for legacy servers with API version < 100


### 0.15.0 - June 2024
---

- Support modern label printing API
- Improved display of stock item serial numbers
- Updated translations

### 0.14.3 - April 2024
---

- Support "active" field for Company model
- Support "active" field for SupplierPart model
- Adjustments to barcode scanning workflow
- Updated translations

### 0.14.2 - February 2024
---

- Updated error reporting
- Support for updated server API endpoints
- Updated translations

### 0.14.1 - January 2024
---

- Squashing bugs

### 0.14.0 - December 2023
---

- Adds support for Sales Orders
- Adds option to pause and resume barcode scanning with camera
- Adds option for "single shot" barcode scanning with camera
- Fixes bug when removing entire quantity of a stock item
- Add line items to purchase orders directly from the app
- Add line items to purchase order using barcode scanner
- Add line items to sales orders directly from the app
- Add line items to sales order using barcode scanner
- Allocate stock items against existing sales orders

### 0.13.0 - October 2023
---

- Adds "wedge scanner" mode, allowing use with external barcode readers
- Add ability to scan in received items using supplier barcodes
- Store API token, rather than username:password
- Ensure that user will lose access if token is revoked by server
- Improve scroll-to-refresh behaviour across multiple widgets


### 0.12.8 - September 2023
---

- Added extra options for transferring stock items
- Fixes bug where API data was not fetched with correct locale

### 0.12.7 - August 2023
---

- Bug fix for Supplier Part editing page
- Bug fix for label printing (blank template names)
- Updated translations

### 0.12.6 - July 2023
--- 

- Enable label printing for stock locations
- Enable label printing for parts
- Updated translation support
- Bug fixes

### 0.12.5 - July 2023
---

- Adds extra filtering options for stock items
- Updated translations

### 0.12.4 - July 2023
---

- Pre-fill stock location when transferring stock amount
- UX improvements for searching data
- Updated translations

### - 0.12.3 - June 2023
---

- Edit part parameters from within the app
- Increase visibility of stock quantity in widgets
- Improved filters for stock list
- Bug fix for editing stock item purchase price

### 0.12.2 - June 2023
---

- Adds options for configuring screen orientation
- Improvements to barcode scanning
- Translation updates
- Bug fix for scrolling long lists

### 0.12.1 - May 2023
---

- Fixes bug in purchase order form

### 0.12.0 - April 2023
---

- Add support for Project Codes
- Improve purchase order support
- Fix action button colors
- Improvements for stock item test result display
- Added Norwegian translations
- Fix serial number field when creating stock item

### 0.11.5 - April 2023
---

- Fix background image transparency for dark mode
- Fix link to Bill of Materials from Part screen
- Improvements to supplier part detail screen
- Add "notes" field to more models


### 0.11.4 - April 2023
---

- Bug fix for stock history widget
- Improved display of stock history widget
- Theme improvements for dark mode

### 0.11.3 - April 2023
---

- Fixes text color in dark mode

### 0.11.2 - April 2023
---

- Adds "dark mode" display option
- Add action to issue a purchase order
- Add action to cancel a purchase order
- Reimplement periodic checks for notifications


### 0.11.1 - April 2023
---

- Fixes keyboard bug in search widget
- Adds ability to create new purchase orders directly from the app
- Adds support for the "contact" field to purchase orders
- Improved rendering of status codes for stock items
- Added rendering of status codes for purchase orders

### 0.11.0 - April 2023
---

- Major UI updates - [see the documentation](https://docs.inventree.org/en/latest/app/app/)
- Adds globally accessible action button for "search"
- Adds globally accessible action button for "barcode scan"
- Implement context actions using floating actions buttons
- Support barcode scanning for purchase orders

### 0.10.2 - March 2023
---

- Adds support for proper currency rendering
- Fix icon for supplier part detail widget
- Support global search API endpoint
- Updated translations

### 0.10.1 - February 2023 
---

- Add support for attachments on Companies
- Fix duplicate scanning of barcodes
- Updated translations

### 0.10.0 - February 2023
---

- Add support for Supplier Parts
- Updated translations

### 0.9.3 - February 2023
---

- Updates to match latest server API
- Bug fix for empty HttpResponse from server

### 0.9.2 - December 2022
---

- Support custom icons for part category
- Support custom icons for stock location
- Adjustments to notification messages
- Assorted bug fixes
- Updated translations

### 0.9.1 - December 2022
---

- Bug fixes for custom barcode actions
- Updated translations

### 0.9.0 - December 2022
---

- Added support for custom barcodes for Parts
- Added support for custom barcode for Stock Locations
- Support Part parameters
- Add support for structural part categories
- Add support for structural stock locations
- Allow deletion of attachments via app
- Adds option for controlling BOM display
- Updated translations


### 0.8.3 - September 2022
---

- Display list of assemblies which components are used in
- Fixes search input bug

### 0.8.2 - August 2022
---

- Allow serial numbers to be specified when creating new stock items
- Allow serial numbers to be edited for existing stock items
- Allow app locale to be changed manually
- Improved handling of certain errors

### 0.8.1 - August 2022
---

- Added extra filtering options for PartCategory list
- Added extra filtering options for StockLocation list
- Fixed bug related to null widget context
- Improved error handling and reporting

### 0.8.0 - July 2022
---

- Display part variants in the part detail view
- Display Bill of Materials in the part detail view
- Indicate available quantity in stock detail view
- Adds configurable filtering to various list views
- Allow stock location to be "scanned" into another location using barcode
- Improves server connection status indicator on home screen
- Display loading indicator during long-running operations
- Improved error handling and reporting

### 0.7.3 - June 2022
---

- Adds ability to display link URLs in attachments view
- Updated translations

### 0.7.2 - June 2022
---

- Add "quarantined" status flag for stock items
- Extends attachment support to stock items
- Extends attachment support to purchase orders

### 0.7.1 - May 2022
---

- Fixes issue which prevented text input in search window
- Remove support for legacy stock adjustment API
- App now requires server API version 20 (or newer)
- Updated translation files

### 0.7.0 - May 2022
---

- Refactor home screen display
- Display notification messages from InvenTree server
- Fixes duplicated display of units when showing stock quantity
- Adds ability to locate / identify stock items or locations (requires server plugin)
- Improve rendering of home screen when server is not connected
- Adds ability to load global and user settings from the server
- Translation updates

### 0.6.2 - April 2022
---

- Fixes issues related to locale support (for specific locales)

### 0.6.1 - April 2022
---

- Fixes critical bug which prevented app launch on Android

### 0.6.0 - April 2022
---

- Enables printing of stock item labels
- Allow users to manually delete stock items
- Adds option to enable or disable strict HTTPs certificate checks
- Multiple bug fixes for form entry
- Adds translation support for Czech
- Adds translation support for Farsi (Persian)
- Adds translation support for Hungarian
- Adds translation support for Indonesian
- Adds translation support for Portuguese
- Adds translation support for Portuguese (Brazilian)
- Increased translation coverage

### 0.5.6 - January 2022
---

- Fixes bug related to transferring stock via barcode scanning
- Updated UI for settings
- Adds ability to disable "upload error report" functionality

### 0.5.5 - January 2022
---

- Fixes bug in stock item creation form

### 0.5.4 - January 2022
---

- Enable usage of camera flash when scanning barcodes
- Enable camera toggle when scanning barcodes
- Configurable home screen actions
- Updated icon set
- Removed "upload error report" functionality (instead link to GitHub issues)
- Updated multiple language translations

### 0.5.3 - November 2021
---

- Check for null value when reading user permissions
- Updated Italian language translations
- Updated French language translations

### 0.5.2 - October 2021
---

- Display error message on HTTPS certificate error

### 0.5.1 - October 2021
---

- Bug fix for app title

### 0.5.0 - October 2021
---

- Major UI overhaul
- Adds many more options to the home screen
- Adds global "drawer" - accessible via long-press of the "back" button
- Display Purchase Order details
- Edit Purchase Order information
- Adds ability to receive stock items against purchase orders
- Display Company details (supplier / manufacturer / customer)
- Edit Company information
- Improvements to stock adjustment actions
- Improvements to barcode scanning
- Fixed bug relating to stock transfer for parts with specified "units"
- Multiple other small bug fixes

### 0.4.7 - September 2021
---

- Display units after stock quantity
- Support multi-byte UTF characters in API transactions
- Updated translations

### 0.4.6 - August 2021
---

- Improved profile selection screen
- Fixed a number of incorrect labels
- Refactor test result upload functionality
- Refactor file selection and upload functions

### 0.4.5 - August 2021
---

- Adds ability to create new Part Categories
- Adds ability to create new Parts
- Adds ability to create new Stock Locations
- Adds ability to create new Stock Items
- Adds ability to view and download attachments for Parts
- Adds ability to upload new part attachments
- App bar now always displays "back" button
- Display "batch code" information for stock item
- Display "packaging" information for stock item
- Multiple bug fixes

### 0.4.3 - August 2021
---

- Multiple bug fixes, mostly related to API calls

### 0.4.2 - August 2021
---

- Simplify process for uploading part images
- Display total stock "on order" for purchaseable parts
- Display supplier information for purchaseable parts
- Handle error responses from server when scanning barcodes
- Handle error responses from server when fetching model data
- Update translation strings

### 0.4.1 - July 2021
---

- Null reference bug fix
- Update translations

### 0.4.0 - July 2021
---

- Fixes bug which prevented opening of external URLs
- Adds ability to edit Part notes
- Adds ability to edit StockItem notes


### 0.3.1 - July 2021
---

- Adds new "API driven" forms
- Improvements for Part editing form
- Improvements for PartCategory editing form
- Improvements for StockLocation editing form
- Adds ability to edit StockItem
- Display purchase price (where available) for StockItem
- Updated translations
- Adds support for more languages

### 0.2.10 - July 2021
---

- Add "last updated" date to StockDetail view
- Add "stocktake" date to StockDetail view
- Display location of stock items in list view

### 0.2.9 - July 2021
---

- Handle 50x responses from server
- Improved reporting of error messages

### 0.2.8 - July 2021
---

- Bug fixes for API calls


### 0.2.7 - July 2021
---

- Fixed errors in error-handling code

### 0.2.6 - July 2021
---

- Major code update with "null safety" features
- Handle case of improperly formatted hostname
- Multiple API bug fixes (mostly null references)
- Updated translations

### 0.2.5 - June 2021
---

- Fixed bug associated with scanning a StockItem into a non-existent location
- Improved error reporting

### 0.2.4 - June 2021
---

- Upload Part images from phone camera or gallery
- Display error message for improperly formatted server address
- Updated version numbering scheme to match InvenTree server

### 0.1.5 - May 2021
---

- Added ability for user to submit feedback
- Update translations

### 0.1.4 - April 2021
---

- Fixes certificate issues connecting to HTTPs server
- Fixes some app crash bugs
- Bug fixes for various API calls
- Improved error messages for invalid user credentials
- UI cleanup

### 0.1.3 - March 2021
---

- Adds ability to toggle "star" status for Part
- Fixes form display bug for stock adjustment actions
- User permissions are now queried from the InvenTree server
- Any "unauthorized" actions are now not displayed
- Uses server-side pagination, providing a significant increase in UI performance
- Adds audio feedback for server errors and barcode scanning
- Adds "app settings" view

### 0.1.2 - February 2021
---

- Fixes bug which caused blank screen when opening barcode scanner

### 0.1.1 - February 2021
---

- Fixes crash bug on top-level part category
- Fixed crash bug on top-level stock location
- Adds context overlay to barcode scanner view
- Notifications are less obtrusive (uses snack bar)
- Fixed search views - keyboard search button now works properly

### 0.1.0 - February 2021
---
This is the initial release of the InvenTree app.

InvenTree documentation available at https://inventree.rtfd.io

Available features as described below:

- Initial app version release
- Navigate through Part tree
- Edit Parts
- Navigate through Stock tree
- Search for Part(s)
- Scan barcode to redirect to various views
- Use barcode scanner to perform various stock actions
- Manage multiple user / server profiles
