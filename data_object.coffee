# These are the columns that YNAB expects
ynab_cols = ['Date','Payee','Category','Memo','Outflow','Inflow']

# Converts a string value into a number.
# Filters out all special characters like $ or ,
numberfy = (val) ->
  # Convert val into empty string if it is undefined or null
  if !val?
    val = ''

  if isNaN(val)
    # replace any commas with colon because Danish!
    val = val.replace(/,/g, ".")
    # check for negative signs or parenthases.
    is_negative = if (val.match("-") || val.match(/\(.*\)/)) then -1 else 1
    # return just the number and make it negative if needed.
    +(val.match(/\d+.?\d*/)[0]) * is_negative
  else
    val

# Uses moment.js to parse and format the date into the correct format
parseDate = (val) -> moment(val,'DD-MM-YYYY').format('MM/DD/YYYY') if val && val.length > 0


# This class does all the heavy lifting.
# It takes the and can format it into csv
class window.DataObject
  constructor: () ->
    @base_json = null

  # Parse base csv file as JSON. This will be easier to work with.
  # It uses http://papaparse.com/ for handling parsing
  parse_csv: (csv) -> @base_json = unescape(encodeURIComponent(Papa.parse(csv, {
    "header": true,
    "delimiter": ';',
    "encoding": 'ISO-8859-1',
    "skipEmptyLines": true
  })))
  fields: -> @base_json.meta.fields
  rows: -> @base_json.data

s
  # This method converts base_json into a json file with YNAB specific fields based on
  #   which fields you choose in the dropdowns in the browser.
  #
  # --- parameters ----
  # limit: expects and integer and limits how many rows get parsed (specifically for preview)
  #     pass in false or null to do all.
  # lookup: hash definition of YNAB column names to selected base column names. Lets us
  #     convert the uploaded CSV file into the columns that YNAB expects.
  converted_json: (limit, lookup) ->
    return nil if @base_json == null
    value = []

    # TODO: You might want to check for errors. Papaparse has an errors field.
    if @base_json.data
      @base_json.data.forEach (row, index) ->
        if !limit || index < limit
          tmp_row = {}
          ynab_cols.forEach (col) ->
            cell = row[lookup[col]]

            # Some YNAB columns need special formatting,
            #   the rest are just returned as they are.
            switch col
              when 'Date' then tmp_row[col] = parseDate(cell)
              when 'Outflow'
                number = numberfy(cell)
                if lookup['Outflow'] == lookup['Inflow']
                  tmp_row[col] = Math.abs(number) if number < 0
                else
                  tmp_row[col] = number
              when 'Inflow'
                number = numberfy(cell)
                if lookup['Outflow'] == lookup['Inflow']
                  tmp_row[col] = number if number > 0
                else
                  tmp_row[col] = number
              else tmp_row[col] = cell

          value.push(tmp_row)
    value

  converted_csv: (limit, lookup) ->
    return nil if @base_json == null
    # Papa.unparse string
    string = ynab_cols.join(',') + "\n"
    @.converted_json(limit, lookup).forEach (row) ->
      row_values = []
      ynab_cols.forEach (col) ->
        row_values.push row[col]
      string += row_values.join(',') + "\n"
    string
