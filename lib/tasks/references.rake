namespace :russ do
  namespace :references do
    desc "Nummeriert Referenz-Positionen lueckenlos nach aktueller Sortierung neu"
    task renumber_positions: :environment do
      total = Reference.count

      Reference.renumber_positions!

      puts "Renumbered #{total} references."
    end
  end
end
