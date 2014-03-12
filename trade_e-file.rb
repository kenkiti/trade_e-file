# -*- coding: utf-8 -*-
# 楽天取引履歴CSVファイルのヘッダー
# 0 約定日, 1 受渡日, 2 銘柄コード, 3 銘柄名, 4 市場名称, 5 口座区分, 6 取引区分, 7 売買区分
# 8 信用区分, 9 弁済期限, 10 数量［株］, 11 単価［円］, 12 手数料［円］, 13 税金等［円］, 14 諸費用［円］
# 15, 税区分, 16 受渡金額［円］, 17 建約定日, 18 建単価［円］, 19 建手数料［円］, 20 建手数料消費税［円］
# 21 金利（支払）〔円〕, 22 金利（受取）〔円〕, 23 逆日歩（支払）〔円〕, 24 逆日歩（受取）〔円〕, 25 貸株料
# 26 事務管理費〔円〕（税抜）, 27 名義書換料〔円〕（税抜）

# --- 取引に関する情報
# 0 約定日, 1 受渡日, 2 銘柄コード, 3 銘柄名, 4 市場名称, 5 口座区分, 
# 6 取引区分, 7 売買区分, 8 信用区分, 9 弁済期限, 15 税区分, 17 建約定日, 18 建単価［円］
# --- 金額
# 10 数量［株］, 11 単価［円］, 16 受渡金額［円］
# --- 経費
# 12 手数料［円］, 13 税金等［円］, 14 諸費用［円］

require 'csv'
require 'optparse'

Version = "0.0.1"

class Rakuten
  attr_accessor :date, :code, :name, :torihiki, :baibai, :amount, :value, :cost

  def initialize(e)
    @date = e[0]
    @code = e[2] # 銘柄コード
    @name = e[3] # 銘柄名称
    @torihiki = e[6] # 取引区分
    @baibai = e[7] # 売買区分
    @amount = e[10].gsub(",","").to_i # 株数
    @value  = e[11].gsub(",","").to_i # 単価
    @cost = [12,13,14].inject(0) {|sum, i| sum += e[i].gsub(",","").to_i } # 諸経費（手数料+税金+諸費用）
  end 

  def self.csv_reader(csv)
    # header.each_with_index {|e, i| print "#{i} #{e}, "}; puts 
    reader = CSV.open(csv, "r", encoding: "Shift_JIS:UTF-8")
    header = reader.take(1)[0] 
    reader
  end
end

class Total
  attr_reader :code, :name
  attr_accessor :chk, :buy, :sell, :cost

  def initialize(e)
    @code = e[2]
    @name = e[3]
    @chk = 0
    @buy = 0
    @sell = 0
    @cost = 0
  end

  def buy?(baibai)
    baibai =~ /買付|買建|買埋/
  end

  def sell?(baibai)
    baibai =~ /売付|売埋|売建/
  end

  def add_chk(v,baibai) # チェック用
    @chk += v.amount if buy?(baibai)
    @chk -= v.amount if sell?(baibai)
  end

  def add_sellbuy(v,baibai) # 購入金額と売却金額
    @buy  += v.amount * v.value if buy?(baibai)
    @sell += v.amount * v.value if sell?(baibai)
  end
end

if $0 == __FILE__
  csv_file = nil # "tradehistory(JP)_20140225.csv"
  verbose = false
  ARGV.options do |opt|
    opt.on("-c", "--csv FILE", "input tradehistory from csv file") { |v| csv_file = v }
    opt.on("-v", "--verbose", "more info") { |v| verbose = true }
    opt.parse!
  end
  if csv_file.nil?
    puts ARGV.options
    exit 
  end

  # 各銘柄毎の購買金額、売却金額、経費の集計
  t = {}
  reader = Rakuten.csv_reader(csv_file)
  reader.each do |row|
    v = Rakuten.new(row)
    t[v.code] = Total.new(row) unless t.has_key?(v.code) 
    t[v.code].add_chk(v, v.baibai) # チェック用
    t[v.code].add_sellbuy(v, v.baibai)
    t[v.code].cost += v.cost # 経費
  end

  # 分割・繰り越しチェック
  is_disagree = false
  t.sort.each do |k, v|
    unless v.chk == 0
      puts "#{k}:#{v.name}, 不足株数: #{v.chk}" 
      is_disagree = true
  end
  end

  if is_disagree
  puts "--------------------------------------"
    puts "上記銘柄の新規・返済株の数量が一致しません。分割や年をまたいで持ち越している銘柄がないか確認し修正してください。"
    exit
  end

  # 銘柄毎の収支ランキング
  t.sort_by{|k,v| -(v.sell-v.buy-v.cost) }.each do |code, v|
    puts "#{code}, #{v.name}, #{v.sell-v.buy-v.cost}"
  end

  # 総計
  buy, sell, cost = t.values.map{|x| [x.buy, x.sell, x.cost]}.transpose.map {|x| x.reduce(:+)}
  puts "--------------------------------------"
  puts "損益:#{sell-buy-cost}, 買:#{buy}, 売:#{sell}, 経費:#{cost}"
end


