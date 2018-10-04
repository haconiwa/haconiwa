module Haconiwa
  module Hookable
    VALID_HOOKS = [
      :setup,
      :before_fork,
      :after_fork,
      :before_chroot,
      :after_chroot,
      :before_start_wait,
      :teardown_container,
      :teardown,
      :after_reload,
      :after_failure,
      :system_failure,
      :before_restore,
      :after_restore,
    ]

    def self.valid?(hookpoint)
      VALID_HOOKS.include?(hookpoint)
    end

    def invoke_general_hook(hookpoint, base)
      hook = base.general_hooks[hookpoint]
      hook.call(base) if hook
    rescue Exception => e
      Logger.warning("General container hook at #{hookpoint.inspect} failed. Skip")
      Logger.warning("#{e.class} - #{e.message}")
    end
  end
end
