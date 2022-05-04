## InvenTree App Release Notes
---

### 0.7.0 -
---

- Refactor home screen display

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
