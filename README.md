# Parallizer - Execute your service layer in parallel.

Parallizer lets you execute slow and expensive methods on an object in parallel threads then later call those methods without a performance hit. Its primarily intended to be used by the client using service libraries that make multiple network calls.

## Examples

### Parallizing an object

An example service class:

    require 'net/http'
    
    class SearchService
        def get_foo_search_result_page
            Net::HTTP.get('www.google.com', '/?q=foo')
        end
        
        def get_bar_search_result_page
            Net::HTTP.get('www.google.com', '/?q=foo')
        end
    end
    
Now create a proxy for that service that has executed the specified methods in parallel:

    require 'parallizer'
    
    parallizer = Parallizer.new(SearchService.new)
    parallizer.add.get_foo_search_result_page
    parallizer.add.get_bar_search_result_page
    search_service = parallizer.execute

Now use that service proxy in your application logic:

    puts search_service.get_foo_search_result_page
    puts search_service.get_foo_search_result_page

Additional calls in your application logic will not result in an additional call to the underlying service.

    # Called twice, but no extra service call. (Be careful not to mutate the returned object!)
    puts search_service.get_foo_search_result_page
    puts search_service.get_foo_search_result_page

If there is an additional method on your service that was not parallized, you can still call it:

    puts search_service.get_foobar_search_result_page

### Parallizing methods with parameters

Parallizing also works on service methods with parameters:

    require 'net/http'
    require 'cgi'

    class SearchService
        def search_result(search_term)
            Net::HTTP.get('www.google.com', "/?q=#{CGI.escape(search_term)}")
        end
    end

The parallel execution and proxy creation:

    parallizer = Parallizer.new(SearchService.new)
    parallizer.add.search_result('foo')
    parallizer.add.search_result('bar')
    search_service = parallizer.execute

Using the service proxy in your application logic:

    puts search_service.search_result('foo') # returns stored value
    puts search_service.search_result('bar') # returns stored value
    puts search_service.search_result('foobar') # does a Net::HTTP.get call


### Parallizing class methods

You can even parallize class methods:

    require 'net/http'
    require 'parallizer'

    # Parallize setup
    parallizer = Parallizer.new(Net::HTTP)
    parallizer.add.get('www.google.com', '/?q=foo')
    parallizer.add.get('www.google.com', '/?q=bar')
    http_service = parallizer.execute

Use the service proxy:

    # use your service proxy
    http_service.get('www.google.com', '/?q=foo') # returns stored value
    http_service.get('www.google.com', '/?q=bar') # returns stored value
    http_service.get('www.google.com', '/?q=foobar') # does a Net::HTTP.get call


# Credits

Always Execute is maintained by [Michael Pearce](http://github.com/michaelgpearce) and is funded by [BookRenter.com](http://www.bookrenter.com "BookRenter.com").

![BookRenter.com Logo](http://assets0.bookrenter.com/images/header/bookrenter_logo.gif "BookRenter.com")

# Copyright

Copyright (c) 2012 Michael Pearce, Bookrenter.com. See LICENSE.txt for further details.

