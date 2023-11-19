module Capybara
  module Lockstep
    class Server
      include Logging

      def initialize
        @job_count = 0
        @job_count_mutex = Mutex.new
        @idle_condition = ConditionVariable.new
      end

      attr_accessor :job_count

      def start_work(tag)
        job_count_mutex.synchronize do
          self.job_count += 1
          log("Started server work: #{tag} [#{job_count} server jobs]") if tag
        end
      end

      def stop_work(tag)
        job_count_mutex.synchronize do
          self.job_count -= 1
          log("Stopped server work: #{tag} [#{job_count} server jobs]") if tag

          if job_count == 0
            idle_condition.broadcast
          end
        end
      end

      def synchronize
        job_count_mutex.synchronize do
          if job_count > 0
            idle_condition.wait(job_count_mutex)
          end
        end
      end

      private

      attr_reader :job_count_mutex, :idle_condition

    end
  end
end
