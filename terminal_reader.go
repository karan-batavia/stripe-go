//
//
// File generated from our OpenAPI spec
//
//

package stripe

// The reason for the refund.
type TerminalReaderActionRefundPaymentReason string

// List of values that TerminalReaderActionRefundPaymentReason can take
const (
	TerminalReaderActionRefundPaymentReasonDuplicate           TerminalReaderActionRefundPaymentReason = "duplicate"
	TerminalReaderActionRefundPaymentReasonFraudulent          TerminalReaderActionRefundPaymentReason = "fraudulent"
	TerminalReaderActionRefundPaymentReasonRequestedByCustomer TerminalReaderActionRefundPaymentReason = "requested_by_customer"
)

// Type of information to be displayed by the reader.
type TerminalReaderActionSetReaderDisplayType string

// List of values that TerminalReaderActionSetReaderDisplayType can take
const (
	TerminalReaderActionSetReaderDisplayTypeCart TerminalReaderActionSetReaderDisplayType = "cart"
)

// Status of the action performed by the reader.
type TerminalReaderActionStatus string

// List of values that TerminalReaderActionStatus can take
const (
	TerminalReaderActionStatusFailed     TerminalReaderActionStatus = "failed"
	TerminalReaderActionStatusInProgress TerminalReaderActionStatus = "in_progress"
	TerminalReaderActionStatusSucceeded  TerminalReaderActionStatus = "succeeded"
)

// Type of action performed by the reader.
type TerminalReaderActionType string

// List of values that TerminalReaderActionType can take
const (
	TerminalReaderActionTypeProcessPaymentIntent TerminalReaderActionType = "process_payment_intent"
	TerminalReaderActionTypeProcessSetupIntent   TerminalReaderActionType = "process_setup_intent"
	TerminalReaderActionTypeRefundPayment        TerminalReaderActionType = "refund_payment"
	TerminalReaderActionTypeSetReaderDisplay     TerminalReaderActionType = "set_reader_display"
)

// Type of reader, one of `bbpos_wisepad3`, `stripe_m2`, `bbpos_chipper2x`, `bbpos_wisepos_e`, `verifone_P400`, or `simulated_wisepos_e`.
type TerminalReaderDeviceType string

// List of values that TerminalReaderDeviceType can take
const (
	TerminalReaderDeviceTypeBBPOSChipper2X    TerminalReaderDeviceType = "bbpos_chipper2x"
	TerminalReaderDeviceTypeBBPOSWisePad3     TerminalReaderDeviceType = "bbpos_wisepad3"
	TerminalReaderDeviceTypeBBPOSWisePOSE     TerminalReaderDeviceType = "bbpos_wisepos_e"
	TerminalReaderDeviceTypeSimulatedWisePOSE TerminalReaderDeviceType = "simulated_wisepos_e"
	TerminalReaderDeviceTypeStripeM2          TerminalReaderDeviceType = "stripe_m2"
	TerminalReaderDeviceTypeVerifoneP400      TerminalReaderDeviceType = "verifone_P400"
)

// Updates a Reader object by setting the values of the parameters passed. Any parameters not provided will be left unchanged.
type TerminalReaderParams struct {
	Params `form:"*"`
	// Custom label given to the reader for easier identification. If no label is specified, the registration code will be used.
	Label *string `form:"label"`
	// The location to assign the reader to.
	Location *string `form:"location"`
	// A code generated by the reader used for registering to an account.
	RegistrationCode *string `form:"registration_code"`
}

// Returns a list of Reader objects.
type TerminalReaderListParams struct {
	ListParams `form:"*"`
	// Filters readers by device type
	DeviceType *string `form:"device_type"`
	// A location ID to filter the response list to only readers at the specific location
	Location *string `form:"location"`
	// A status filter to filter readers to only offline or online readers
	Status *string `form:"status"`
}

// Configuration overrides
type TerminalReaderProcessPaymentIntentProcessConfigParams struct {
	// Override showing a tipping selection screen on this transaction.
	SkipTipping *bool `form:"skip_tipping"`
}

// Initiates a payment flow on a Reader.
type TerminalReaderProcessPaymentIntentParams struct {
	Params `form:"*"`
	// PaymentIntent ID
	PaymentIntent *string `form:"payment_intent"`
	// Configuration overrides
	ProcessConfig *TerminalReaderProcessPaymentIntentProcessConfigParams `form:"process_config"`
}

// Initiates a setup intent flow on a Reader.
type TerminalReaderProcessSetupIntentParams struct {
	Params `form:"*"`
	// Customer Consent Collected
	CustomerConsentCollected *bool `form:"customer_consent_collected"`
	// SetupIntent ID
	SetupIntent *string `form:"setup_intent"`
}

// Cancels the current reader action.
type TerminalReaderCancelActionParams struct {
	Params `form:"*"`
}

// Array of line items that were purchased.
type TerminalReaderSetReaderDisplayCartLineItemParams struct {
	// The price of the item in cents.
	Amount *int64 `form:"amount"`
	// The description or name of the item.
	Description *string `form:"description"`
	// The quantity of the line item being purchased.
	Quantity *int64 `form:"quantity"`
}

// Cart
type TerminalReaderSetReaderDisplayCartParams struct {
	// Three-letter [ISO currency code](https://www.iso.org/iso-4217-currency-codes.html), in lowercase. Must be a [supported currency](https://stripe.com/docs/currencies).
	Currency *string `form:"currency"`
	// Array of line items that were purchased.
	LineItems []*TerminalReaderSetReaderDisplayCartLineItemParams `form:"line_items"`
	// The amount of tax in cents.
	Tax *int64 `form:"tax"`
	// Total balance of cart due in cents.
	Total *int64 `form:"total"`
}

// Sets reader display to show cart details.
type TerminalReaderSetReaderDisplayParams struct {
	Params `form:"*"`
	// Cart
	Cart *TerminalReaderSetReaderDisplayCartParams `form:"cart"`
	// Type
	Type *string `form:"type"`
}

// Initiates a refund on a Reader
type TerminalReaderRefundPaymentParams struct {
	Params `form:"*"`
	// A positive integer in __cents__ representing how much of this charge to refund.
	Amount *int64 `form:"amount"`
	// ID of the Charge to refund.
	Charge *string `form:"charge"`
	// ID of the PaymentIntent to refund.
	PaymentIntent *string `form:"payment_intent"`
	// Boolean indicating whether the application fee should be refunded when refunding this charge. If a full charge refund is given, the full application fee will be refunded. Otherwise, the application fee will be refunded in an amount proportional to the amount of the charge refunded. An application fee can be refunded only by the application that created the charge.
	RefundApplicationFee *bool `form:"refund_application_fee"`
	// Boolean indicating whether the transfer should be reversed when refunding this charge. The transfer will be reversed proportionally to the amount being refunded (either the entire or partial amount). A transfer can be reversed only by the application that created the charge.
	ReverseTransfer *bool `form:"reverse_transfer"`
}

// Represents a per-transaction override of a reader configuration
type TerminalReaderActionProcessPaymentIntentProcessConfig struct {
	// Override showing a tipping selection screen on this transaction.
	SkipTipping bool `json:"skip_tipping"`
}

// Represents a reader action to process a payment intent
type TerminalReaderActionProcessPaymentIntent struct {
	// Most recent PaymentIntent processed by the reader.
	PaymentIntent *PaymentIntent `json:"payment_intent"`
	// Represents a per-transaction override of a reader configuration
	ProcessConfig *TerminalReaderActionProcessPaymentIntentProcessConfig `json:"process_config"`
}

// Represents a reader action to process a setup intent
type TerminalReaderActionProcessSetupIntent struct {
	GeneratedCard string `json:"generated_card"`
	// Most recent SetupIntent processed by the reader.
	SetupIntent *SetupIntent `json:"setup_intent"`
}

// Represents a reader action to refund a payment
type TerminalReaderActionRefundPayment struct {
	// The amount being refunded.
	Amount int64 `json:"amount"`
	// Charge that is being refunded.
	Charge *Charge `json:"charge"`
	// Payment intent that is being refunded.
	PaymentIntent *PaymentIntent `json:"payment_intent"`
	// The reason for the refund.
	Reason TerminalReaderActionRefundPaymentReason `json:"reason"`
	// Unique identifier for the refund object.
	Refund *Refund `json:"refund"`
	// Boolean indicating whether the application fee should be refunded when refunding this charge. If a full charge refund is given, the full application fee will be refunded. Otherwise, the application fee will be refunded in an amount proportional to the amount of the charge refunded. An application fee can be refunded only by the application that created the charge.
	RefundApplicationFee bool `json:"refund_application_fee"`
	// Boolean indicating whether the transfer should be reversed when refunding this charge. The transfer will be reversed proportionally to the amount being refunded (either the entire or partial amount). A transfer can be reversed only by the application that created the charge.
	ReverseTransfer bool `json:"reverse_transfer"`
}

// List of line items in the cart.
type TerminalReaderActionSetReaderDisplayCartLineItem struct {
	// The amount of the line item. A positive integer in the [smallest currency unit](https://stripe.com/docs/currencies#zero-decimal).
	Amount int64 `json:"amount"`
	// Description of the line item.
	Description string `json:"description"`
	// The quantity of the line item.
	Quantity int64 `json:"quantity"`
}

// Cart object to be displayed by the reader.
type TerminalReaderActionSetReaderDisplayCart struct {
	// Three-letter [ISO currency code](https://www.iso.org/iso-4217-currency-codes.html), in lowercase. Must be a [supported currency](https://stripe.com/docs/currencies).
	Currency Currency `json:"currency"`
	// List of line items in the cart.
	LineItems []*TerminalReaderActionSetReaderDisplayCartLineItem `json:"line_items"`
	// Tax amount for the entire cart. A positive integer in the [smallest currency unit](https://stripe.com/docs/currencies#zero-decimal).
	Tax int64 `json:"tax"`
	// Total amount for the entire cart, including tax. A positive integer in the [smallest currency unit](https://stripe.com/docs/currencies#zero-decimal).
	Total int64 `json:"total"`
}

// Represents a reader action to set the reader display
type TerminalReaderActionSetReaderDisplay struct {
	// Cart object to be displayed by the reader.
	Cart *TerminalReaderActionSetReaderDisplayCart `json:"cart"`
	// Type of information to be displayed by the reader.
	Type TerminalReaderActionSetReaderDisplayType `json:"type"`
}

// The most recent action performed by the reader.
type TerminalReaderAction struct {
	// Failure code, only set if status is `failed`.
	FailureCode string `json:"failure_code"`
	// Detailed failure message, only set if status is `failed`.
	FailureMessage string `json:"failure_message"`
	// Represents a reader action to process a payment intent
	ProcessPaymentIntent *TerminalReaderActionProcessPaymentIntent `json:"process_payment_intent"`
	// Represents a reader action to process a setup intent
	ProcessSetupIntent *TerminalReaderActionProcessSetupIntent `json:"process_setup_intent"`
	// Represents a reader action to refund a payment
	RefundPayment *TerminalReaderActionRefundPayment `json:"refund_payment"`
	// Represents a reader action to set the reader display
	SetReaderDisplay *TerminalReaderActionSetReaderDisplay `json:"set_reader_display"`
	// Status of the action performed by the reader.
	Status TerminalReaderActionStatus `json:"status"`
	// Type of action performed by the reader.
	Type TerminalReaderActionType `json:"type"`
}

// A Reader represents a physical device for accepting payment details.
//
// Related guide: [Connecting to a Reader](https://stripe.com/docs/terminal/payments/connect-reader).
type TerminalReader struct {
	APIResource
	// The most recent action performed by the reader.
	Action  *TerminalReaderAction `json:"action"`
	Deleted bool                  `json:"deleted"`
	// The current software version of the reader.
	DeviceSwVersion string `json:"device_sw_version"`
	// Type of reader, one of `bbpos_wisepad3`, `stripe_m2`, `bbpos_chipper2x`, `bbpos_wisepos_e`, `verifone_P400`, or `simulated_wisepos_e`.
	DeviceType TerminalReaderDeviceType `json:"device_type"`
	// Unique identifier for the object.
	ID string `json:"id"`
	// The local IP address of the reader.
	IPAddress string `json:"ip_address"`
	// Custom label given to the reader for easier identification.
	Label string `json:"label"`
	// Has the value `true` if the object exists in live mode or the value `false` if the object exists in test mode.
	Livemode bool `json:"livemode"`
	// The location identifier of the reader.
	Location *TerminalLocation `json:"location"`
	// Set of [key-value pairs](https://stripe.com/docs/api/metadata) that you can attach to an object. This can be useful for storing additional information about the object in a structured format.
	Metadata map[string]string `json:"metadata"`
	// String representing the object's type. Objects of the same type share the same value.
	Object string `json:"object"`
	// Serial number of the reader.
	SerialNumber string `json:"serial_number"`
	// The networking status of the reader.
	Status string `json:"status"`
}

// TerminalReaderList is a list of Readers as retrieved from a list endpoint.
type TerminalReaderList struct {
	APIResource
	ListMeta
	Data []*TerminalReader `json:"data"`
}
