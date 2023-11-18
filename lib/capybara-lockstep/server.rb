module Capybara
  module Lockstep
    class Server
      class << self

        def job_count
          @job_count ||= 0
        end

        attr_writer :job_count

        def start_work(tag)
          tagger_mutex.synchronize do
            if job_count == 0
              mutex.lock
            end

            self.job_count += 1
            Lockstep.log("Started server work: #{tag} [#{job_count} server jobs]")
          end
        end

        def stop_work(tag)
          tagger_mutex.synchronize do
            self.job_count -= 1
            Lockstep.log("Stopped server work: #{tag} [#{job_count} server jobs]")

            if job_count == 0
              mutex.unlock
            end
          end
        end

        def synchronize
          synchronizer_mutex.synchronize { }
        end

        private

        def synchronizer_mutex
          @synchronize_mutex ||= Mutex.new
        end

        def tagger_mutex
          @tagger_mutex ||= Mutex.new
        end

      end
    end
  end
end

