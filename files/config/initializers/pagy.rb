# frozen_string_literal: true

require "pagy"
Pagy::DEFAULT[:limit] = 25 if Pagy::DEFAULT.is_a?(Hash) && !Pagy::DEFAULT.frozen?
