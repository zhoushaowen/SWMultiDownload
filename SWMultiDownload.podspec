Pod::Spec.new do |s|

  s.name         = "SWMultiDownload"

  s.version      = "0.0.1"

  s.homepage      = 'https://github.com/zhoushaowen/SWMultiDownload'

  s.ios.deployment_target = '7.0'

  s.summary      = "多线程下载大文件框架"

  s.license      = { :type => 'MIT', :file => 'LICENSE' }

  s.author       = { "Zhoushaowen" => "348345883@qq.com" }

  s.source       = { :git => "https://github.com/zhoushaowen/SWMultiDownload.git", :tag => s.version }
  
  s.source_files  = "SWMultiDownload/SWMultiDownload/*.{h,m}"
  
  s.requires_arc = true

end