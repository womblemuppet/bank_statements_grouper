require 'csv'

require_relative 'counterparty.rb'

start_time = Time.now
puts "Start: #{start_time.strftime("%H:%M:%S")}"


def open_transactions_file
  #SLUUUURP
  transactions = CSV.foreach("input/transactions.csv", headers: true, header_converters: :symbol).map(&:to_hash)

  return transactions
end

def load_counterparties_file
  if !File.file?("output/counterparties.csv")
    CSV.open("output/counterparties.csv", "a+") do |csv|
      csv << [:name, :category]
    end

    return {}
  end

  counterparties_by_identifier = CSV.foreach(
    "output/counterparties.csv",
    headers: true,
    header_converters: :symbol
  ) 
  .inject({}) do |acc, saved_counterparty_data|
    new_counterparty = Counterparty.new(
      name: saved_counterparty_data[:name],
      category: saved_counterparty_data[:category]
    )

    acc[new_counterparty.identifier] = new_counterparty
    next acc
  end

  return counterparties_by_identifier
  
end

def save_new_counterparties(new_counterparties)
  CSV.open("output/counterparties.csv", "a+") do |csv|
    new_counterparties.each do |counterparty|
      csv_row = CSV::Row.new([:name, :category], [counterparty.name, counterparty.category])
      csv << csv_row
    end
  end

end

def ask_for_category_for_counterparties(transactions)
  new_counterparties_by_name = {}

  transactions.each do |transaction|
    transaction_prompt = if transaction[:particulars] != "************"
      "#{transaction[:other_party]} (#{transaction[:particulars]})"
    else
      transaction[:other_party]
    end

    puts "Please categorise #{transaction_prompt}"
    inputted_category = gets().strip().downcase()

    new_counterparty = Counterparty.new(name: transaction[:other_party], category: inputted_category)

    new_counterparties_by_name[transaction[:other_party]] = new_counterparty
  end

  return new_counterparties_by_name
end

transactions = open_transactions_file()

existing_counterparties_by_name = load_counterparties_file()

new_counterparties_by_name = {}
transactions_to_categorise_new_counterparty = []

transactions.each do |transaction|
  next if existing_counterparties_by_name[transaction[:other_party]]

  ## could replace this with fuzzy match - would want separate CounterpartyStore class or something?
  identifier = Counterparty::make_identifier_from_name(transaction[:other_party])

  related_counterparty = existing_counterparties_by_name[identifier]
  if related_counterparty
    new_counterparty = Counterparty.new(name: transaction[:other_party], category: related_counterparty.category)
    new_counterparties_by_name[transaction[:other_party]] = new_counterparty
  else
    transactions_to_categorise_new_counterparty << transaction
  end

end

newly_categorised_counterparties_by_name = ask_for_category_for_counterparties(transactions_to_categorise_new_counterparty)

new_counterparties_to_save = [*newly_categorised_counterparties_by_name.values, *new_counterparties_by_name.values]
save_new_counterparties(new_counterparties_to_save)

all_counterparties_by_name = existing_counterparties_by_name.merge(
  new_counterparties_by_name,
  newly_categorised_counterparties_by_name
)

transactions_by_category = transactions.group_by do |transaction|
  all_counterparties_by_name[transaction[:other_party]].category
end

stats_by_category = transactions_by_category.transform_values do |transactions|
  total = transactions.sum { |transaction| transaction[:amount].to_f }
  frequency = transactions.length
  average = total / frequency

  next { total: total.round(2), frequency: frequency, average: average.round(2) }
end.sort_by do |category, stats|
  stats[:total] 
end.to_h.reject do |category, stats|
  next ( ["debit", "investments", "gifts", ].include?(category) )
end

def make_sankey_output(stats_by_category)
  income_stats_by_category, expenditure_stats_by_category = stats_by_category.partition do |category, stats|
    stats[:total] > 0
  end

  income_streams = income_stats_by_category.map do |category, stats|
    next "#{category.capitalize()} [#{stats[:total]}] Budget"
  end

  expenditure_streams = expenditure_stats_by_category.map do |category, stats|
    next "Budget [#{ stats[:total].abs() }] #{category.capitalize()}"
  end

  sankey_output = [*income_streams, "", *expenditure_streams].join("\n")
  return sankey_output
end

sankey_output = make_sankey_output(stats_by_category)
File.write("output/sankey_output.txt", sankey_output)


elapsed_time = Time.at(Time.now - start_time)
puts "Elapsed: #{elapsed_time.strftime("%Mm:%Ss:%L")}"

