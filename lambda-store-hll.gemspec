Gem::Specification.new do |s|
    s.name = 'lambda-store-hll'
    s.version = '0.0.1'
    s.date = '2020-12-01'
    s.summary = 'A library to add hyperloglog functionality to lambda store in ruby'

    s.authors = ['Aiden Leeming']
    s.homepage = 'https://github.com/Aidenjl193/lambda-store-hll'

    s.license = 'MIT'

    s.add_development_dependency 'bundler'

    s.files = [
        'lib/lambda-store-hll.rb',
        'lib/lambda-store-hll/counter.rb'
    ]
    s.require_paths = ['lib']

    s.add_dependency 'redis'
    s.add_dependency 'mmh3'
end