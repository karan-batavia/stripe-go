//
//
// File generated from our OpenAPI spec
//
//

package stripe

import "encoding/json"

// Retrieve a list of features
type EntitlementsFeatureListParams struct {
	ListParams `form:"*"`
	// Specifies which fields in the response should be expanded.
	Expand []*string `form:"expand"`
}

// AddExpand appends a new field to expand.
func (p *EntitlementsFeatureListParams) AddExpand(f string) {
	p.Expand = append(p.Expand, &f)
}

// Creates a feature
type EntitlementsFeatureParams struct {
	Params `form:"*"`
	// Specifies which fields in the response should be expanded.
	Expand []*string `form:"expand"`
	// A unique key you provide as your own system identifier. This may be up to 80 characters.
	LookupKey *string `form:"lookup_key"`
	// The feature's name, for your own purpose, not meant to be displayable to the customer.
	Name *string `form:"name"`
}

// AddExpand appends a new field to expand.
func (p *EntitlementsFeatureParams) AddExpand(f string) {
	p.Expand = append(p.Expand, &f)
}

// A feature represents a monetizable ability or functionality in your system.
// Features can be assigned to products, and when those products are purchased, Stripe will create an entitlement to the feature for the purchasing customer.
type EntitlementsFeature struct {
	APIResource
	// Unique identifier for the object.
	ID string `json:"id"`
	// Has the value `true` if the object exists in live mode or the value `false` if the object exists in test mode.
	Livemode bool `json:"livemode"`
	// A unique key you provide as your own system identifier. This may be up to 80 characters.
	LookupKey string `json:"lookup_key"`
	// The feature's name, for your own purpose, not meant to be displayable to the customer.
	Name string `json:"name"`
	// String representing the object's type. Objects of the same type share the same value.
	Object string `json:"object"`
}

// EntitlementsFeatureList is a list of Features as retrieved from a list endpoint.
type EntitlementsFeatureList struct {
	APIResource
	ListMeta
	Data []*EntitlementsFeature `json:"data"`
}

// UnmarshalJSON handles deserialization of an EntitlementsFeature.
// This custom unmarshaling is needed because the resulting
// property may be an id or the full struct if it was expanded.
func (e *EntitlementsFeature) UnmarshalJSON(data []byte) error {
	if id, ok := ParseID(data); ok {
		e.ID = id
		return nil
	}

	type entitlementsFeature EntitlementsFeature
	var v entitlementsFeature
	if err := json.Unmarshal(data, &v); err != nil {
		return err
	}

	*e = EntitlementsFeature(v)
	return nil
}
