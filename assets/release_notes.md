## InvenTree App Release Notes
---

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