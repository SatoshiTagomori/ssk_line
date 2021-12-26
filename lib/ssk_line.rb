require 'ht_req'
module SskLine

    #セッションに現在のcsrfトークンを入れて、
    #Lineログイン用のURLを返す関数
    def self.login_url(request)
        if self.env_not_exist?(request) then return false end 
        request.session[:line_csrf] = request.session[:_csrf_token]
        'https://access.line.me/oauth2/v2.1/authorize?response_type=code&client_id='+ENV['LINEAPI_CHANNEL_ID']+'&redirect_uri='+ENV['LINEAPI_CALLBACK_URL']+'&state='+request.session[:line_csrf]+'&scope=profile%20openid'    
    end
    
    #最低限の設定がされているかのチェック
    def self.status_check(request,controller,user_class)
       request.flash[:danger]=''
       self.env_key_check(request,'LINEAPI_CHANNEL_ID')
       self.env_key_check(request,'LINEAPI_CALLBACK_URL')
       self.env_key_check(request,'LINEAPI_CHANNEL_SECRET')
       self.instance_method_check(request,user_class,:teacher)
       self.instance_method_check(request,user_class,:admin)
       self.instance_method_check(request,user_class,:lineid)
       self.instance_method_check(request,user_class,:dname)
       self.instance_method_check(request,user_class,:picture)
       if request.flash[:danger].length > 0 then return false else return true end
    end
    
    def self.instance_method_check(request,user_class,key)
       if user_class.new.methods.include?(key) == false then request.flash[:danger] =','+user_class.name.to_s+'に'+key.to_s+'が存在しません' end
    end
    
    def self.env_key_check(request,key)
        if ENV.has_key?(key) == false then request.flash[:danger]=',環境変数'+key+'が存在しません' end
    end
    
    def self.login_process(line_profile,user_class,request)
        line_profile.has_key?("pictureUrl") ? picture = line_profile["pictureUrl"] : picture = nil
        #最初のユーザーは管理者にする。それ以外は初期値としては管理者にしない
        user_class::count == 0 ? admin = true : admin = false
        #ユーザーが存在しなければ
        if user_class::where('lineid =  ?',line_profile["userId"]).count == 0
            #新規ユーザーとして追加
            user = user_class.create(:lineid =>line_profile["userId"],:dname=>line_profile["displayName"],:picture=>picture,:admin=>admin,:teacher=>false)
        else
            user=user_class.find_by(:lineid => line_profile["userId"])
            user.update(:dname=>line_profile["displayName"],:picture=>picture)
        end
        request.session[:user_id]=user.id
    end
    
    def self.get_line_profile(access_token)
        res = HtReq.get_json_data({
          :method => 'GET',
          :url => 'https://api.line.me/v2/profile',
          :params =>{},
          :header=>{'Authorization'=>'Bearer '+access_token}
        })
        if res then return res else return false end
    end
    
    def self.get_access_token(request,controller)
        if request.params.has_key?(:code) == false then request.flash[:danger] = 'codeがありません' and return false end
        res = HtReq.get_json_data({
          :method => 'POST',
          :url => 'https://api.line.me/oauth2/v2.1/token',
          :params =>{
            'grant_type'=>'authorization_code',
            'code'=>request.params[:code],
            'redirect_uri'=>ENV['LINEAPI_CALLBACK_URL'],
            'client_id'=>ENV['LINEAPI_CHANNEL_ID'],
            'client_secret'=>ENV['LINEAPI_CHANNEL_SECRET']
          },
          :header=>{'Content-Type'=>'application/x-www-form-urlencoded'}
        })
        if res then return res["access_token"] else return false end
    end
    
    
    def self.line_login_process(request,controller,user_class)
        if self.status_check(request,controller,user_class) == false then controller.redirect_to controller.root_path and return false end
        if self.line_csrf_check(request) == false then controller.redirect_to controller.root_path and return false end
        access_token = self.get_access_token(request,controller)
        if access_token == false then controller.redirect_to controller.root_path and request.flash[:danger]='アクセストークンが取得できません。' and return false end
        profile = self.get_line_profile(access_token)
        if profile == false then controller.redirect_to controller.root_path and request.flash[:danger]='LINEアカウントのプロフィールが取得できません。' and return false end
        self.login_process(profile,user_class,request)
        return true
    end
    
    def self.line_csrf_check(request)
        #ログインしていないのにstateがなければfalse
        if request.params.has_key?(:state) == false then request.flash[:danger] = 'ログインしてください' and return false end
        #セッションにline_csrfがなければfalse
        if request.session.has_key?(:line_csrf) === false then request.flash[:danger] = 'ログインしてください' and return false end
        #トークンが一致しなければfalse、一致していればセッションからline_csrfを削除
        if request.params[:state] == request.session[:line_csrf] then request.session.delete(:line_csrf) and return true else request.flash[:danger]='トークンが一致しません' and return false end
    end
    
    private
    
    def self.env_not_exist?(request)
        if ENV.has_key?('LINEAPI_CHANNEL_ID') && ENV.has_key?('LINEAPI_CALLBACK_URL') && ENV.has_key?('LINEAPI_CHANNEL_SECRET')
           return false
        else
            request.flash.now[:danger]='SskLineを使用するために必要な環境変数が設定されておりません'
            return true
        end
    end
    
end


