//
//
// File generated from our OpenAPI spec
//
//

// Package event provides the /events APIs
package event

import (
	"net/http"

	stripe "github.com/stripe/stripe-go/v76"
	"github.com/stripe/stripe-go/v76/form"
)

// Client is used to invoke /events APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// Get returns the details of an event.
func Get(id string, params *stripe.EventParams) (*stripe.Event, error) {
	return getC().Get(id, params)
}

// Get returns the details of an event.
func (c Client) Get(id string, params *stripe.EventParams) (*stripe.Event, error) {
	path := stripe.FormatURLPath("/v1/events/%s", id)
	event := &stripe.Event{}
	var err error
	sr := stripe.StripeRequest{Method: http.MethodGet, Path: path, Key: c.Key}
	err = sr.SetParams(params)
	if err != nil {
		return nil, err
	}
	err = c.B.Call(sr, event)
	return event, err
}

// List returns a list of events.
func List(params *stripe.EventListParams) *Iter {
	return getC().List(params)
}

// List returns a list of events.
func (c Client) List(listParams *stripe.EventListParams) *Iter {
	return &Iter{
		Iter: stripe.GetIter(listParams, func(p *stripe.Params, b *form.Values) ([]interface{}, stripe.ListContainer, error) {
			list := &stripe.EventList{}
			sr := stripe.StripeRequest{
				Method: http.MethodGet,
				Path:   "/v1/events",
				Key:    c.Key,
			}
			err := sr.SetRawForm(p, b)
			if err != nil {
				return nil, list, err
			}
			err = c.B.Call(sr, list)

			ret := make([]interface{}, len(list.Data))
			for i, v := range list.Data {
				ret[i] = v
			}

			return ret, list, err
		}),
	}
}

// Iter is an iterator for events.
type Iter struct {
	*stripe.Iter
}

// Event returns the event which the iterator is currently pointing to.
func (i *Iter) Event() *stripe.Event {
	return i.Current().(*stripe.Event)
}

// EventList returns the current list object which the iterator is
// currently using. List objects will change as new API calls are made to
// continue pagination.
func (i *Iter) EventList() *stripe.EventList {
	return i.List().(*stripe.EventList)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
