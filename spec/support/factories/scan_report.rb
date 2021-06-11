Factory.define :report_data do

    {
        application: MockApp,
        seed:     Cuboid::Utilities.random_seed,
        options:  Cuboid::Options.to_hash,
        start_datetime:  Time.now - 10_000,
        finish_datetime: Time.now
    }
end

Factory.define :report do
    Cuboid::Report.new Factory[:report_data]
end

Factory.define :report_empty do
    Cuboid::Report.new
end
