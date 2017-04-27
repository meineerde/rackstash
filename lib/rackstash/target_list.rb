module Rackstash
  class TargetList
    def initialize(*targets)
      @targets = Concurrent::Array.new

      targets.flatten.each do |target|
        add(target)
      end
    end

    def <<(target)
      target = Target.new(target) unless target.is_a?(Target)
      @targets << target
      self
    end
    alias add <<

    def [](index)
      @targets[index]
    end

    def []=(index, target)
      target = Target.new(target) unless target.is_a?(Target)
      @targets[index] = target
    end

    def empty?
      @targets.empty?
    end

    def inspect
      id_str = (object_id << 1).to_s(16).rjust(DEFAULT_OBJ_ID_STR_WIDTH, '0')
      "#<#{self.class.name}:0x#{id_str} #{self}>"
    end

    def length
      @targets.length
    end
    alias size length

    def to_ary
      @targets.to_a
    end
    alias to_a to_ary

    def to_s
      @targets.to_s
    end
  end
end
