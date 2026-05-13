module ApplicationHelper
  def public_page?(key)
    @page_key == key.to_sym
  end

  def public_section?(keys)
    keys.map(&:to_sym).include?(@page_key)
  end

  def public_nav_aria(keys)
    { aria: { current: "page" } } if public_section?(Array(keys))
  end

  def public_nav_class(keys, class_name: "is-active")
    class_name if public_section?(Array(keys))
  end
end
