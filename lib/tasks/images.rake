namespace :images do
  desc "Optimize existing Russ Live uploads for web delivery"
  task optimize_uploads: :environment do
    stats = RussExistingImageUploadOptimizer.call

    puts "Optimierte Bilder: #{stats[:optimized]}"
    puts "Fehlende Dateien: #{stats[:missing]}" if stats[:missing].positive?
    puts "Fehler: #{stats[:failed]}" if stats[:failed].positive?
  end
end
