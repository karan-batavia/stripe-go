//
//
// File generated from our OpenAPI spec
//
//

package stripe

// The meter event adjustment's status.
type BillingMeterEventAdjustmentStatus string

// List of values that BillingMeterEventAdjustmentStatus can take
const (
	BillingMeterEventAdjustmentStatusComplete BillingMeterEventAdjustmentStatus = "complete"
	BillingMeterEventAdjustmentStatusPending  BillingMeterEventAdjustmentStatus = "pending"
)

// Specifies whether to cancel a single event or a range of events for a time period.
type BillingMeterEventAdjustmentType string

// List of values that BillingMeterEventAdjustmentType can take
const (
	BillingMeterEventAdjustmentTypeCancel BillingMeterEventAdjustmentType = "cancel"
)

// Specifies which event to cancel.
type BillingMeterEventAdjustmentCancelParams struct {
	// Unique identifier for the event.
	Identifier *string `form:"identifier"`
}

// Creates a billing meter event adjustment
type BillingMeterEventAdjustmentParams struct {
	Params `form:"*"`
	// Specifies which event to cancel.
	Cancel *BillingMeterEventAdjustmentCancelParams `form:"cancel"`
	// The name of the meter event. Corresponds with the `event_name` field on a meter.
	EventName *string `form:"event_name"`
	// Specifies which fields in the response should be expanded.
	Expand []*string `form:"expand"`
	// Specifies whether to cancel a single event or a range of events for a time period.
	Type *string `form:"type"`
}

// AddExpand appends a new field to expand.
func (p *BillingMeterEventAdjustmentParams) AddExpand(f string) {
	p.Expand = append(p.Expand, &f)
}

type BillingMeterEventAdjustmentCancel struct {
	// Unique identifier for the event.
	Identifier string `json:"identifier"`
}

// A billing meter event adjustment represents the status of a meter event adjustment.
type BillingMeterEventAdjustment struct {
	APIResource
	Cancel *BillingMeterEventAdjustmentCancel `json:"cancel"`
	// The name of the meter event. Corresponds with the `event_name` field on a meter.
	EventName string `json:"event_name"`
	// Has the value `true` if the object exists in live mode or the value `false` if the object exists in test mode.
	Livemode bool `json:"livemode"`
	// String representing the object's type. Objects of the same type share the same value.
	Object string `json:"object"`
	// The meter event adjustment's status.
	Status BillingMeterEventAdjustmentStatus `json:"status"`
	// Specifies whether to cancel a single event or a range of events for a time period.
	Type BillingMeterEventAdjustmentType `json:"type"`
}
