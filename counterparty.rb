class Counterparty
  attr_reader :name, :category, :identifier

  def initialize(name:, category:)
    @name = name
    @category = category

    @transactions = []
    @identifier = Counterparty::make_identifier_from_name(name)
  end

  def self.make_identifier_from_name(name)
    ## pattern match?
    if name =~ /(.*) \d+/
      return Regexp.last_match[1]
    else
      return name
    end

  end
  
end
