require 'minitest/autorun'

class LruCache
    def initialize
        @values = {}
        @max_size = 10
    end
    
    def get(key)
        if @values.has_key?(key) 
            # マイクロ秒精度なので正直あんまりイケてないですね
            @values[key][:used_at] = Time.now.instance_eval { self.to_i * 1000000 + usec }
            @values[key][:value]
        else
            nil
        end
    end
    
    def set(key, value)
        # 新規キーの場合は一番古いキーを削除、キー値更新の場合は削除をスルー
        self.remove(least_recently_used_key) unless self.keys.include?(key) if size >= @max_size

        @values[key] = {
            value: value,
            used_at: nil
        }
    end
    
    def remove(key)
        @values.delete(key)
    end
    
    def keys
        @values.keys
    end
    
    def size
        @values.size 
    end
    
    private
    def least_recently_used_key
        @values.sort_by{|k, v| v[:used_at].to_i}.first.first
    end
end

class TestLruCache < Minitest::Test
    def setup
        @cache = LruCache.new
    end
    
    def test_set_and_get_1_value
        @cache.set('some_key', 'some_value')
        assert_equal 'some_value', @cache.get('some_key'), '値を1個セットし、セットした値を取得する'
        assert_equal 1, @cache.size, '値を1個セットした時、キーの数が1個になる'
    end
    
    def test_set_and_get_10_values
        (1..10).each do |i|
            @cache.set("some_key#{i}", "some_value#{i}")
        end

        (1..10).each do |i|
            assert_equal "some_value#{i}", @cache.get("some_key#{i}"), '値を10個セットし、セットした値を取得する'
        end
        
        assert_equal 10, @cache.size, '異なるキー値を10個セットした時、キーの数が10個になる'
    end
    
    def test_set_11_values
        set_keys = []
        (1..11).each do |i|
            @cache.set("some_key#{i}", "some_value#{i}")
            set_keys.push("some_key#{i}")
        end
        
        missing_key = set_keys - @cache.keys
        refute_empty missing_key, '異なるキー値を11個セットした時、削除されたキーが存在する'
        assert_equal 10, @cache.size, '異なるキー値を11個セットした時、キーの数が10個になる'
    end
    
    def test_remove_lru_key_when_set
        (1..10).each do |i|
            @cache.set("some_key#{i}", "some_value#{i}")
            @cache.get("some_key#{i}")
        end
        # some_key1-10の連番順に使用したため、'some_key1'が削除される
        @cache.set('another_key1', 'another_value1')
        assert_equal nil, @cache.get('some_key1'), '値セット時にキー数が10を超える場合、最も使われていないキーが削除される'
        assert_equal 10, @cache.size, 'キーを10個を超えてセットしてもキーの数は10個になる'
        
        # セット直後のキーは使われていないため、'another_key1'が削除される
        @cache.set('another_key2', 'another_value2')
        assert_equal nil, @cache.get('another_key1'), '値セット時にキー数が10を超える場合、最も使われていないキーが削除される'
        assert_equal 10, @cache.size, 'キーを10個を超えてセットしてもキーの数は10個になる'
        
        # some_key2を使用したため、次に最も使われていない'some_key3'が削除される
        @cache.get('another_key2')
        @cache.get('some_key2')
        @cache.set('another_key3', 'another_value3')
        assert_equal nil, @cache.get('some_key3'), '値セット時にキー数が10を超える場合、最も使われていないキーが削除される'
        assert_equal 10, @cache.size, 'キーを10個を超えてセットしてもキーの数は10個になる'
        
        # some_key2を再セットすると未使用キー扱いとなるため、新規キー追加時に削除される
        @cache.get('another_key3')
        @cache.set('some_key2', 'new_value')
        @cache.set('another_key4', 'another_value4')
        assert_equal nil, @cache.get('some_key2'), '値セット時にキー数が10を超える場合、最も使われていないキーが削除される'
        assert_equal 10, @cache.size, 'キーを10個を超えてセットしてもキーの数は10個になる'
    end
    
    def test_set_and_remove_values
        (1..10).each do |i|
            @cache.set("some_key#{i}", "some_value#{i}")
            @cache.get("some_key#{i}")
        end
        assert_equal 10, @cache.size, '異なるキー値を10個セットした時、キーの数が10個になる'
        
        @cache.remove('some_key5')
        assert_equal 9, @cache.size, 'キーを削除した時、キーの数が減少する'
        assert_equal nil, @cache.get('some_key5'), 'キーを削除した時、値が取得できなくなる'
        @cache.set('some_key11', 'some_value11')
        assert_equal 10, @cache.size, '10個を超えないキーを追加した時、キーの数が増加する'
    end
    
    def test_get_empty_value
        assert_equal nil, @cache.get('not_set'), '存在しないキーを参照した場合、nilを返す'
    end
end
