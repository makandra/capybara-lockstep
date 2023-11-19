module Capybara
  module Lockstep
    class Server
      include Logging

      def job_count
        @job_count ||= 0
      end

      attr_writer :job_count

      def start_work(tag)
        tagger_mutex.synchronize do
          # if job_count == 0
          #   synchronizer_mutex.lock
          # end

          self.job_count += 1
          log("Started server work: #{tag} [#{job_count} server jobs]")
        end
      end

      def stop_work(tag)
        tagger_mutex.synchronize do
          self.job_count -= 1
          log("Stopped server work: #{tag} [#{job_count} server jobs]")

          # if job_count == 0
          #   synchronizer_mutex.unlock
          # end
        end
      end

      def synchronize
        synchronizer_mutex.synchronize { }
      end

      private

      def synchronizer_mutex
        @synchronizer_mutex ||= Mutex.new
      end

      def tagger_mutex
        @tagger_mutex ||= Mutex.new
      end
    end
  end
end
