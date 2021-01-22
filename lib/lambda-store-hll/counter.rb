require 'mmh3'

module LambdaStoreHLL
    class Counter

        def initialize(redis, b: 10)
            raise "Accuracy not supported. Please choose a value of b between 4 and 16" if b < 4 || b > 16
            @b = b
            @m = 2 ** b
            @redis = redis
            @hash_len = 32 - b
            @alpha = 0.7213/(1 + 1.079/@m)
        end

        ADD_SCRIPT = '
        local index = tonumber(KEYS[2])
        local counter = redis.call("GETRANGE", KEYS[1], index, index)
        local str_len = tonumber(ARGV[2])

        if(counter == "") then
            local str = ""
            for i=0,str_len-1 do
                str = str .. (i == index and ARGV[1] or string.char(0))
            end
            redis.call("SET", KEYS[1], str)
            return 1
        elseif string.byte(ARGV[1]) > string.byte(counter) then
            redis.call("SETRANGE", KEYS[1], index, ARGV[1])
            return 1
        end

        return 0
        '
        ADD_SCRIPT_MIN = 'local a=tonumber(KEYS[2])local b=redis.call("GETRANGE",KEYS[1],a,a)local c=tonumber(ARGV[2])if b==""then local d=""for e=0,c-1 do d=d..(e==a and ARGV[1]or string.char(0))end;redis.call("SET",KEYS[1],d)return 1 elseif string.byte(ARGV[1])>string.byte(b)then redis.call("SETRANGE",KEYS[1],a,ARGV[1])return 1 end;return 0'

        COUNT_SCRIPT = '
        local m = tonumber(ARGV[1])
        local alpha = tonumber(ARGV[2])
        local value = 0
        local length = 0

        local str = redis.call("GET", KEYS[1])

        if not str then
            return 0
        end

        for i=1,m do
            local max = string.byte(str:sub(i,i))
            if max > 0 then
                length = length + 1
            end
            value = value + 0.5 ^ max
        end

        local estimate = m ^ 2 * alpha / value

        --linear count
        if estimate < 2.5 * m and (length < m) then
            return (m * math.log(m/(m - length)))  
        end

        return math.floor(estimate + 0.5)
        '
        COUNT_SCRIPT_MIN = 'local a=tonumber(ARGV[1])local b=tonumber(ARGV[2])local c=0;local d=0;local e=redis.call("GET",KEYS[1])if not e then return 0 end;for f=1,a do local g=string.byte(e:sub(f,f))if g>0 then d=d+1 end;c=c+0.5^g end;local h=a^2*b/c;if h<2.5*a and d<a then return a*math.log(a/(a-d))end;return math.floor(h+0.5)'

        # do the hashing on this end to save excessive amounts of script being sent
        def add(k, v)
            #hash the string
            hash = Mmh3.hash32(v)
            #remove negatives but keep info
            hash = ((hash.abs << 1) | (hash.negative? ? 1 : 0))

            #get the 10 bit bucket id
            int_bucket = (hash & (@m - 1))

            @redis.eval(ADD_SCRIPT_MIN, :keys => [k, int_bucket], :argv => [rho(hash / @m).chr, @m])
        end
        
        def count(k)
            @redis.eval(COUNT_SCRIPT_MIN, :keys => [k], :argv => [@m, @alpha])
        end

        def del(k)
            @redis.del(k)
        end

        private

        def rho(i)
            return @hash_len + 1 if i == 0
            @hash_len - Math.log(i, 2).floor
        end
    end
end