const HTTPS = require('https')
const showdown = require('showdown');
const markdownConverter = new showdown.Converter();

const excludedFields = {
    all: [
        'object',
        // metadata is special cased in the data mapper
        'metadata',
        'expand'
    ],

    customer: [],

    product: [
        // not essential to exclude the ID, but not using a standard ID makes maintaining an account confusing
        'id',
        'price'
    ],

    subscription_schedule: [
        // the customer relationship is managed directly by the integration, omit in the UI
        'customer'
    ],

    // TODO we aren't really representing a subscription item here, we are representing a subscription schedule phase item which is slightly different
    //      this is why all of the fields below are excluded
    subscription_item: [
        'payment_behavior',
        'proration_behavior',
        'proration_date',
        'subscription',

        // these would be excluded from the subscription schedule phase item as well
        'price',
        'price_data'
    ],

    price: [
        // product<>price relationship is managed directly by the integration, we should ignore
        'product',
        'product_data'
    ],

    subscription_schedule_phase: [
        'proration_behavior'
    ],
    coupon: [
        'id',
        'currency',
        'redeem_by'
    ]
}

const ListOfStripeObjects = [
    'customer',
    'product',
    'subscription_schedule',
    'subscription_item',
    'price',
    'coupon'
]

const OPTIONS = {
    hostname: 'raw.githubusercontent.com',
    port: 443,
    path: 'stripe/openapi/da45da6a10b8824937baab2232c8f92a84b820c2/openapi/spec3.json',
    method: 'GET'
}

let openApiSpec = '';

function extractStripeObject(openApiSpec, stripeObjectType) {
    return openApiSpec['paths'][`/v1/${stripeObjectType}s`]['post']['requestBody']['content']['application/x-www-form-urlencoded']['schema']['properties'];
}

function extractSubscriptionPhaseObject(openApiSpec) {
    return extractStripeObject(openApiSpec, 'subscription_schedule')['phases']['items']['properties'];
}

// TODO we should use async/await here instead
const HTTPREQUEST = HTTPS.request(OPTIONS, HttpResponse => {
    HttpResponse.on('data', responseDataChunk => {
        openApiSpec += responseDataChunk.toString();
    })

    HttpResponse.on('end', () => {
        openApiSpec = JSON.parse(openApiSpec);


        var formattedStripeObjectsForMapper = {};
        for (const stripeObject of ListOfStripeObjects) {
            var convertedObjectName = stripeObject.charAt(0).toUpperCase() + stripeObject.slice(1);

            // TODO change mapper response to match here so there is now need for all this formatting https://github.com/stripe/stripe-salesforce/issues/364
            // NOTE when this naming change is made to the mapper it will require all to upgrade package or the mapper will not work
            switch (stripeObject) {
                case 'subscription_schedule':
                    convertedObjectName = 'Subscription'
                    break;
                case 'subscription_item':
                    convertedObjectName = 'SubscriptionItem'
                    break;
                case 'product':
                    convertedObjectName = 'ProductItem'
                    break;
                default:
                    break;
            }

            formattedStripeObjectsForMapper['formattedStripe' + convertedObjectName + 'Fields'] = formatStripeObjectsForMapper(extractStripeObject(openApiSpec, stripeObject), excludedFields[stripeObject], convertedObjectName.charAt(0).toLowerCase() + convertedObjectName.slice(1));
            if (stripeObject === 'subscription_item') {
                formattedStripeObjectsForMapper['formattedStripeSubscriptionSchedulePhaseFields'] = formatStripeObjectsForMapper(extractSubscriptionPhaseObject(openApiSpec), excludedFields['subscription_schedule_phase'], 'subscriptionSchedulePhase');
            }

            if (convertedObjectName === 'Subscription') {
                formattedStripeObjectsForMapper = manuallyAddSectionToParsedOpenSpec(
                    formattedStripeObjectsForMapper, 
                    convertedObjectName,
                    'Prebilling',
                    'prebilling',
                    'Iterations',
                    'prebilling.iterations',
                    '<p>This is used to determine the number of billing cycles to prebill.</p>',
                    'integer'
                );
          
                // Push fields to 'Default settings Invoice settings' section
                rendering_template_field = getNewFieldObject(
                    "template",
                    "default_settings.invoice_settings.rendering.template",
                    "Invoice rendering template id to use for this subscription\'s invoice",
                    "string");
                rendering_template_version_field = getNewFieldObject(
                    'template version',
                    'default_settings.invoice_settings.rendering.template_version',
                    'Version of the rendering template that will be used. If this field is null, then the latest version of the template will be automatically used.',
                    'integer'); 
                formattedStripeObjectsForMapper['formattedStripe' + convertedObjectName + 'Fields']
                    .find(object => object.name == "default_settings.invoice_settings").fields.push(rendering_template_field, rendering_template_version_field);
            }
        }
        
        formattedStripeObjectsForMapper = JSON.stringify(formattedStripeObjectsForMapper);
        console.log(formattedStripeObjectsForMapper);
        return formattedStripeObjectsForMapper;
    })
})

HTTPREQUEST.on('error', error => {
    console.log(error);
})

HTTPREQUEST.end();

function arrayEquals(a, b) {
    return Array.isArray(a) &&
        Array.isArray(b) &&
        a.length === b.length &&
        a.every((val, index) => val === b[index]);
}


function formatStripeObjectsForMapper(stripeObjectToFormat, objectExcludedReadOnlyFields, stripeObjectName) {
    let stripeObjectMappings = [{
        label: 'Standard Mappings',
        name: 'standard',
        description: '',
        fields: []
    }];

    for (const field in stripeObjectToFormat) {
        if (excludedFields.all.includes(field) || objectExcludedReadOnlyFields.includes(field)) {
            continue;
        }

        const fieldData = stripeObjectToFormat[field];

        // if `type` does not exist, `anyOf` is often provided which provides a list of options
        // in many cases, a enum with an empty string is an option. I'm not sure why, but I believe we can safely filter these out and treat
        // them as a type with anyOf containing the other options
        const acceptableTypes = (fieldData['anyOf'] || []).filter(t => !arrayEquals(t.enum, [''])).map(t => t.type)

        // mapper does not support array mapping
        if(fieldData['type'] === 'array' || arrayEquals(acceptableTypes, ['array'])) {
            continue;
        }

        // if we don't have an object reference, then this is a standard field
        if (
            !fieldData['$ref'] &&
            !acceptableTypes.includes('object') &&

            (fieldData['type'] || '') !== 'object'
        ) {
            let fieldMap = getNewFieldObject(field.replace(/_+/g, ' '), field);
            fieldMap['type'] = fieldData['type'];

            if (fieldData['description']) {
                fieldMap['description'] = markdownConverter.makeHtml(fieldData['description']);
            } else {
                fieldMap = getStripeFieldDescription(fieldMap, field);
            }

            // standard field section is always at the top of the array
            stripeObjectMappings[0].fields.push(fieldMap);
            continue;
        }

        // TODO we do not have the logic below adjusted for the new understanding that `acceptableTypes` could contain *just* an object reference

        if (fieldData['anyOf'] && fieldData['anyOf'].length &&
            openApiSpec['components']['schemas'][field] ) {
            var nestedExpandableFieldMap = openApiSpec['components']['schemas'][field]['properties'];
            if (nestedExpandableFieldMap) {
                stripeObjectMappings = checkforNestedFields(field, stripeObjectToFormat, stripeObjectMappings, nestedExpandableFieldMap, objectExcludedReadOnlyFields);
            }
            continue;
        }

        var expandableSchemaFieldName;
        var expandableSchemaFieldMap;

        /*In this case we are getting the field name assoicated with this object and going to
        '['components']['schemas']' tree path associated with the current field to get the
        related subfields, descriptions and types to add to them mapper*/
        // TODO in what cases does this occur? => in adress and shipping sub-hashes from what I can see
        if (fieldData['$ref']) {
            expandableSchemaFieldName = fieldData['$ref'].split('/').pop();
            expandableSchemaFieldMap = openApiSpec['components']['schemas'][expandableSchemaFieldName]['properties'];
        }

        //In this case we are getting all the descriptions, subfields and types from the object directly
        if (fieldData['type'] === 'object' || fieldData['properties']) {
            expandableSchemaFieldName = field;
            expandableSchemaFieldMap = fieldData['properties'];
        }

        stripeObjectMappings = checkForNestedHashFields(stripeObjectMappings, stripeObjectName, expandableSchemaFieldMap, objectExcludedReadOnlyFields, field, fieldData);
    }

    stripeObjectMappings = stripeObjectMappings.filter(function(section) {
        return section.fields.length > 0;
    });

    // sort all fields alphabetically
    stripeObjectMappings[0].fields.sort((a, b) => a.name.localeCompare(b.name));

    return stripeObjectMappings;
}

function checkforNestedFields(field, stripeObjectToFormat, stripeObjectMappings, nestedExpandableFieldMap, objectExcludedReadOnlyFields) {
    const NEWSECTION = {
        label: field.charAt(0).toUpperCase() + field.slice(1).replace(/_+/g, ' ').replace(/\./g, ' '),
        name: field,
        description: '',
        fields: []
    };

    stripeObjectMappings.push(NEWSECTION);
    for (const expandableField in nestedExpandableFieldMap) {

        if (excludedFields.all.includes(expandableField) || objectExcludedReadOnlyFields.includes(expandableField)) {
            continue;
        }

        if ((nestedExpandableFieldMap[expandableField]['type'] && nestedExpandableFieldMap[expandableField]['type'] !== 'object'
        && nestedExpandableFieldMap[expandableField]['type'] !== 'array' && nestedExpandableFieldMap[expandableField]['description'])) {
            var hashFieldName = expandableField.replace(/_+/g, ' ');
            var hashFieldValue = field + '.' + expandableField;
            let fieldExpandableMap = getNewFieldObject(hashFieldName, hashFieldValue);
            fieldExpandableMap['description'] = markdownConverter.makeHtml(nestedExpandableFieldMap[expandableField]['description']);
            fieldExpandableMap['type'] = nestedExpandableFieldMap[expandableField]['type'];
            stripeObjectMappings[stripeObjectMappings.length - 1].fields.sort(function(a, b) {
                return a.name.localeCompare(b.name);
            });
            var index = stripeObjectMappings.findIndex(objectSection => {
                return objectSection.name === field;
            });

            if (index) {
                stripeObjectMappings[index].fields.push(fieldExpandableMap);
            } else {
                stripeObjectMappings[stripeObjectMappings.length - 1].fields.push(fieldExpandableMap);
            }
        } else {
            if (openApiSpec['components']['schemas'][expandableField] && openApiSpec['components']['schemas'][expandableField]['properties']) {
                var newNestedExpandableFieldMap = openApiSpec['components']['schemas'][expandableField]['properties'];
                var newNestedFieldName = field + '.' + expandableField.charAt(0) + expandableField.slice(1).replace(/_+/g, ' ');
                stripeObjectMappings = checkforNestedFields(newNestedFieldName, stripeObjectToFormat, stripeObjectMappings, newNestedExpandableFieldMap, objectExcludedReadOnlyFields);
            }
        }
    }
    return stripeObjectMappings;
}

function checkForNestedHashFields(stripeObjectMappings, stripeObjectName, expandableSchemaFieldMap, objectExcludedReadOnlyFields, field, fieldData) {

    for (const expandableField in expandableSchemaFieldMap) {
        if (excludedFields.all.includes(expandableField) || objectExcludedReadOnlyFields.includes(expandableField)) {
            continue
        }

        if (expandableSchemaFieldMap[expandableField] && expandableSchemaFieldMap[expandableField]['type'] && expandableSchemaFieldMap[expandableField]['type'] !== 'object') {
            var newSection = {
                label: field.charAt(0).toUpperCase() + field.slice(1).replace(/_+/g, ' '),
                name: field,
                description: '',
                fields: []
            };
            stripeObjectMappings.push(newSection);
            if (Object.keys(expandableSchemaFieldMap).length > 1 ) {
                //checking for further nested hashes in `subscription schedule` default settings hash 2 seperate checks to maintain index
                for (const [nestedSubHashField, nestedSubHashFieldMap] of Object.entries(expandableSchemaFieldMap)) {
                    var nestedSubHashFieldName = nestedSubHashField.replace(/_+/g, ' ');
                    var nestedSubHashFieldValue = field + '.' + nestedSubHashField;
                    if(expandableSchemaFieldMap[nestedSubHashField]['anyOf'] && expandableSchemaFieldMap[nestedSubHashField]['anyOf'].length) {
                        continue
                    } 

                    stripeObjectMappings = addNewFieldToSection(stripeObjectMappings, nestedSubHashFieldName, nestedSubHashFieldValue, nestedSubHashFieldMap, nestedSubHashField, field, stripeObjectName);
                }

                for (const [nestedSubHashField, nestedSubHashFieldMap] of Object.entries(expandableSchemaFieldMap)) {
                    var nestedSubHashFieldName = nestedSubHashField.replace(/_+/g, ' ');
                    var nestedSubHashFieldValue = field + '.' + nestedSubHashField;
        
                    //check to see if the object has a nested list
                    if(expandableSchemaFieldMap[nestedSubHashField]['anyOf'] && expandableSchemaFieldMap[nestedSubHashField]['anyOf'].length) {
                        stripeObjectMappings = getNestedInnerObjectFields(expandableSchemaFieldMap, nestedSubHashField, stripeObjectMappings, field, stripeObjectName);
                    } 
                }

            } else {
                const hashFieldName = expandableField.replace(/_+/g, ' ');
                const hashFieldValue = field + '.' + expandableField;
                stripeObjectMappings = addNewFieldToSection(stripeObjectMappings, hashFieldName, hashFieldValue, expandableSchemaFieldMap, expandableField, field, stripeObjectName);
            }     

        } else if (fieldData['properties'] && fieldData['properties'][expandableField]['properties']) {
            expandableSchemaFieldMap = fieldData['properties'][expandableField]['properties'];

            for (const subfield in expandableSchemaFieldMap) {
                var newSection = {
                    label: field.charAt(0).toUpperCase() + field.slice(1).replace(/_+/g, ' ')+ ' ' +expandableField.charAt(0).toUpperCase() + expandableField.slice(1).replace(/_+/g, ' '),
                    name: [field, expandableField].join("."),
                    description: '',
                    fields: []
                };
                stripeObjectMappings.push(newSection);
                var nestedHashFieldName = subfield.replace(/_+/g, ' ');
                var nestedHashFieldValue = field + '.' + expandableField + '.' + subfield;
                stripeObjectMappings = addNewFieldToSection(stripeObjectMappings, nestedHashFieldName, nestedHashFieldValue, expandableSchemaFieldMap, subfield, field, stripeObjectName);

            }
        } 
    }
    return stripeObjectMappings;
}

function getNestedInnerObjectFields(expandableSchemaFieldMap, nestedSubHashField, stripeObjectMappings, field, stripeObjectName) {
    for (let i = 0; i < expandableSchemaFieldMap[nestedSubHashField]['anyOf'].length; i++) {
        if (!expandableSchemaFieldMap[nestedSubHashField]['anyOf'][i]['properties']) {
            continue;
        }
        nestedExpandableSchemaFieldMap = expandableSchemaFieldMap[nestedSubHashField]['anyOf'][i]['properties'];
        for (const [innerNestedSubHashField, innerNestedSubHashFieldMap] of Object.entries(nestedExpandableSchemaFieldMap)) {
            var newSection = {
                label: field.charAt(0).toUpperCase() + field.slice(1).replace(/_+/g, ' ') + ' ' + nestedSubHashField.charAt(0).toUpperCase() + nestedSubHashField.slice(1).replace(/_+/g, ' '),
                name: nestedSubHashField,
                description: '',
                fields: []
            };
            stripeObjectMappings.push(newSection);
            var innerNestedSubHashFieldName = innerNestedSubHashField.replace(/_+/g, ' ');
            var innerestedSubHashFieldValue = field + '.' + nestedSubHashField + '.' + innerNestedSubHashField;

            stripeObjectMappings = addNewFieldToSection(stripeObjectMappings, innerNestedSubHashFieldName, innerestedSubHashFieldValue, innerNestedSubHashFieldMap, innerNestedSubHashField, field, stripeObjectName);
        }
    }
    return stripeObjectMappings;
}

function addNewFieldToSection(stripeObjectMappings, hashFieldName, hashFieldValue, expandableSchemaFieldMap, expandableField, field, stripeObjectName) {

    let fieldExpandableMap = getNewFieldObject(hashFieldName, hashFieldValue);
    fieldExpandableMap = getStripeFieldDescription(fieldExpandableMap, expandableField);

    //if the field is a hash we get the real stripe field name and find the description in the open spec
    if (hashFieldValue.includes('.') && !fieldExpandableMap['description']) {
      let hashDotPathList = hashFieldValue.split('.')
      let unhashedValue = hashDotPathList[hashDotPathList.length - 1];

      fieldExpandableMap = getStripeFieldDescription(fieldExpandableMap, unhashedValue);
    }

    if (!fieldExpandableMap['type']) {
        fieldExpandableMap = getStripeFieldType(fieldExpandableMap, expandableField);
    } 

    if(fieldExpandableMap['type'] === 'array' || fieldExpandableMap['type'] === 'object') {
        return stripeObjectMappings;
    }
    
    stripeObjectMappings[stripeObjectMappings.length - 1].fields.push(fieldExpandableMap);
    stripeObjectMappings[stripeObjectMappings.length - 1].fields = removeDuplicates(stripeObjectMappings[stripeObjectMappings.length - 1].fields);
    stripeObjectMappings = combineDuplicateSections(stripeObjectMappings);
    return stripeObjectMappings;
}

function removeDuplicates(fieldsList) {
    return fieldsList.filter((object,index,array) => array.findIndex(objectAtIndex => (objectAtIndex.value === object.value)) === index);
}

function combineDuplicateSections(stripeObjectMappings) {
    return stripeObjectMappings.reduce(function(list, obj) {
        var found = false;
        for (var i = 0; i < list.length; i++) {
            if (list[i].name == obj.name) {
                list[i].fields = list[i].fields.concat(obj.fields);
                found = true;
                break;
            }
        }
        if (!found) {
            list.push(obj);
        }
    
        return list;
    }, []);
}

function getNewFieldObject(fieldName, fieldValue, description='', type='') {
    const fieldMap = {
        name: fieldName,
        value: fieldValue,
        description: description,
        type: type,
        defaultValue: '',
        requiredValue: '',
        hasOverride: false,
        staticValue: false,
        hasSfValue: false,
        hasRequiredValue: false,
        sfValue: '',
        sfValueType: ''
    };
    return fieldMap;
}

//finds all object paths to the key based on the object passed in
function getAllPaths(obj, key, prev = '') {
    try {
        const result = []

        for (let k in obj) {
            let path = prev + (prev ? '.' : '') + k;

            if (k == key) {
                result.push(path)
            } else if (typeof obj[k] == 'object') {
                result.push(...getAllPaths(obj[k], key, path))
            }
        }

        return result
    } catch (e) {
        //console.log('error')
        //console.log(JSON.stringify(e))
    }
}

//converts a string dot path to a given key into the actual property of the object passed in
function findIndex(obj, is, value) {
    try {
        if (typeof is == 'string')
            return findIndex(obj,is.split('.'), value);
        else if (is.length==1 && value!==undefined)
            return obj[is[0]] = value;
        else if (is.length==0)
            return obj;
        else
            return findIndex(obj[is[0]],is.slice(1), value);
    } catch (e) {
        //console.log('error')
        //console.log(JSON.stringify(e))
    }
}

//finds the first path in the parsed open spec api where a description exists for a given key
function getStripeFieldDescription(fieldMap, fieldValue) {
    const listOfAllObjectPaths = getAllPaths(openApiSpec, fieldValue);

    for (const objectPath of listOfAllObjectPaths) {
        var nestedValue = findIndex(openApiSpec, objectPath);
        if (nestedValue && nestedValue.description){
            fieldMap['description'] = markdownConverter.makeHtml(nestedValue.description);
            break;
        }
    }
    
    return fieldMap;
}


//finds the first path in the parsed open spec api where a type exists for a given key
function getStripeFieldType(fieldMap, fieldValue) {
    const listOfAllObjectPaths = getAllPaths(openApiSpec, fieldValue);

    for (const objectPath of listOfAllObjectPaths) {
        var nestedValue = findIndex(openApiSpec, objectPath);
        if (nestedValue && nestedValue.type){
            fieldMap['type'] = nestedValue.type;
            break;
        }
    }
    
    if (!fieldMap['type']){
        fieldMap['type'] = 'string';
    }
    
    return fieldMap;
}

function manuallyAddSectionToParsedOpenSpec(formattedStripeObjectsForMapper, convertedObjectName, sectionLabel, sectionName, fieldName, fieldValue, fieldDescription, fieldType) {
    formattedStripeObjectsForMapper['formattedStripe' + convertedObjectName + 'Fields'].push({
        label: sectionLabel,
        name: sectionName,
        description: '',
        fields: [
          {
            name: fieldName,
            value: fieldValue,
            description: fieldDescription,
            type: fieldType,
            defaultValue: '',
            requiredValue: '',
            hasOverride: false,
            staticValue: false,
            hasSfValue: false,
            hasRequiredValue: false,
            sfValue: '',
            sfValueType: ''
          }
        ]
      }
    );
    return formattedStripeObjectsForMapper;
}



