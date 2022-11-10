## General

- List of system level permissions https://developer.salesforce.com/docs/atlas.en-us.sfFieldRef.meta/sfFieldRef/salesforce_field_reference_PermissionSet.htm

## Metadata

- [You cannot specify a default ListView](https://salesforce.stackexchange.com/questions/124447/default-listviews-in-lightning)
- You can't modify most types of metadata once it is created. Be very careful when creating fields. https://developer.salesforce.com/docs/atlas.en-us.236.0.packagingGuide.meta/packagingGuide/modifying_custom_fields.htm
- What metadata is available on the account?
- `sfdx force:mdapi:listmetadata -m Layout` to get all layouts on an account. If you want to pull a namespaced layout: `sfdx force:source:retrieve -m "Layout:Account-SBQQ__CPQ Account Layout"`
- Pull custom field from an account: `sfdx force:source:retrieve -m CustomField:Order.Stripe_Transaction_ID__c`
- Lots of debugging info `sfdx force:source:retrieve -m "Layout:Contract-CPQ Contract Layout" --verbose -u cpq-dev --apiversion=55.0 --dev-debug --loglevel=trace`
- Pull a custom object `sfdx force:source:retrieve -m 'CustomObject:Stripe_Coupon_Beta_Quote_Line_Associatio__c`

## Lighting Web Componetns

- `#lightning` in `pages/setup.page` is where the primary component is mounted

## Apex

- You cannot exit gracefully out of apex early. There is no `exit 0`.
- If `Apex CPU time limit exceeded` is encountered all DB operations are not committed. They are all wrapped into a transaction that is committed at the end of the Apex call.
- You can't do a callout after a DML (DB) operation. TODO I may be getting the order of operations wrong here, look this up
- You can't use variables in the `FROM` clause of a SOQL query `[...]`
- You can't use `*` in a `SELECT` in a SOQL query
- `--loglevel` seems to mess with some commands
- If you run apex anon, `sfdx` seems to truncate logs. The top of the logs won't come through.
- the `Test` helpers ensure all async operations/futures complete before assertions

## SOQL

- `IS NOT NULL` == `field != null`
- There is some fancy relationship syntax. You can use 1:1 lookups in `SELECT` and `WHERE` without a join
- You only `SELECT` via SOQL. All other CRUD operations are done through a ORM-like flow.

## CPQ

- `SBQQ__PriceEditable__c` must be true on the line to customize the price later on
- There are triggers which can suck up API calls on records. Don't let the record count build up!
- If you get something like `APEX_ERROR: SBQQ.RestClient.RefreshTokenNilException: Invalid nil argument: OAuth Refresh Token` it indicates that the SF account is not auth'd into CPQ.

## Packaging

- You'll see an apexdevnet as a remote site https://salesforce.stackexchange.com/questions/33167/apexdevnet-in-the-remote-site
  - Do not include this in the package
- If you edit the URL of a remote site, it won't be updated in a package update. However, admins who have installed the package can manually edit it

## Tools

Most of these are blocked, but still interesting finds:

- https://www.pocketsoap.com/osx/soqlx/#Download
- https://chrome.google.com/webstore/detail/salesforce-inspector/aodjmnfhjibkcdimpodiifdjnnncaafh?hl=en
- https://github.com/motiko/sfdc-debug-logs
