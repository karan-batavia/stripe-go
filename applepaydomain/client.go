//
//
// File generated from our OpenAPI spec
//
//

// Package applepaydomain provides the /apple_pay/domains APIs
package applepaydomain

import (
	"net/http"

	stripe "github.com/stripe/stripe-go/v76"
	"github.com/stripe/stripe-go/v76/form"
)

// Client is used to invoke /apple_pay/domains APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New creates a new apple pay domain.
func New(params *stripe.ApplePayDomainParams) (*stripe.ApplePayDomain, error) {
	return getC().New(params)
}

// New creates a new apple pay domain.
func (c Client) New(params *stripe.ApplePayDomainParams) (*stripe.ApplePayDomain, error) {
	applepaydomain := &stripe.ApplePayDomain{}
	var err error
	sr := stripe.StripeRequest{Method: http.MethodPost, Path: "/v1/apple_pay/domains", Key: c.Key}
	err = sr.SetParams(params)
	if err != nil {
		return nil, err
	}
	err = c.B.Call(sr, applepaydomain)
	return applepaydomain, err
}

// Get returns the details of an apple pay domain.
func Get(id string, params *stripe.ApplePayDomainParams) (*stripe.ApplePayDomain, error) {
	return getC().Get(id, params)
}

// Get returns the details of an apple pay domain.
func (c Client) Get(id string, params *stripe.ApplePayDomainParams) (*stripe.ApplePayDomain, error) {
	path := stripe.FormatURLPath("/v1/apple_pay/domains/%s", id)
	applepaydomain := &stripe.ApplePayDomain{}
	var err error
	sr := stripe.StripeRequest{Method: http.MethodGet, Path: path, Key: c.Key}
	err = sr.SetParams(params)
	if err != nil {
		return nil, err
	}
	err = c.B.Call(sr, applepaydomain)
	return applepaydomain, err
}

// Del removes an apple pay domain.
func Del(id string, params *stripe.ApplePayDomainParams) (*stripe.ApplePayDomain, error) {
	return getC().Del(id, params)
}

// Del removes an apple pay domain.
func (c Client) Del(id string, params *stripe.ApplePayDomainParams) (*stripe.ApplePayDomain, error) {
	path := stripe.FormatURLPath("/v1/apple_pay/domains/%s", id)
	applepaydomain := &stripe.ApplePayDomain{}
	var err error
	sr := stripe.StripeRequest{Method: http.MethodDelete, Path: path, Key: c.Key}
	err = sr.SetParams(params)
	if err != nil {
		return nil, err
	}
	err = c.B.Call(sr, applepaydomain)
	return applepaydomain, err
}

// List returns a list of apple pay domains.
func List(params *stripe.ApplePayDomainListParams) *Iter {
	return getC().List(params)
}

// List returns a list of apple pay domains.
func (c Client) List(listParams *stripe.ApplePayDomainListParams) *Iter {
	return &Iter{
		Iter: stripe.GetIter(listParams, func(p *stripe.Params, b *form.Values) ([]interface{}, stripe.ListContainer, error) {
			list := &stripe.ApplePayDomainList{}
			sr := stripe.StripeRequest{
				Method: http.MethodGet,
				Path:   "/v1/apple_pay/domains",
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

// Iter is an iterator for apple pay domains.
type Iter struct {
	*stripe.Iter
}

// ApplePayDomain returns the apple pay domain which the iterator is currently pointing to.
func (i *Iter) ApplePayDomain() *stripe.ApplePayDomain {
	return i.Current().(*stripe.ApplePayDomain)
}

// ApplePayDomainList returns the current list object which the iterator is
// currently using. List objects will change as new API calls are made to
// continue pagination.
func (i *Iter) ApplePayDomainList() *stripe.ApplePayDomainList {
	return i.List().(*stripe.ApplePayDomainList)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
