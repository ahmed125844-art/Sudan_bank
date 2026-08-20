
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const api = 'http://10.0.2.2:8000';

void main() => runApp(const SudanBank());

class SudanBank extends StatelessWidget {
  const SudanBank({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sudan Bank',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const LoginPage(),
      locale: const Locale('ar'),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState()=>_LoginPageState();
}
class _LoginPageState extends State<LoginPage>{
  final phone=TextEditingController(text:'249900000001');
  final pin=TextEditingController(text:'1234');
  bool loading=false;
  Future<void> login() async {
    setState(()=>loading=true);
    try{
      final r=await http.post(Uri.parse('$api/login'),
        headers:{'Content-Type':'application/json'},
        body:jsonEncode({'phone':phone.text,'pin':pin.text}));
      final d=jsonDecode(r.body);
      if(r.statusCode!=200) throw Exception(d['detail']??'خطأ');
      if(!mounted)return;
      Navigator.pushReplacement(context,MaterialPageRoute(
        builder:(_)=>HomePage(data:d)));
    }catch(e){
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(e.toString())));
    }finally{if(mounted)setState(()=>loading=false);}
  }
  @override Widget build(BuildContext c)=>Directionality(
    textDirection:TextDirection.rtl,
    child:Scaffold(body:Center(child:SingleChildScrollView(
      padding:const EdgeInsets.all(24), child:Column(children:[
        const Icon(Icons.account_balance,size:80),
        const SizedBox(height:16),
        const Text('بنك السودان',style:TextStyle(fontSize:30,fontWeight:FontWeight.bold)),
        const SizedBox(height:30),
        TextField(controller:phone,decoration:const InputDecoration(labelText:'رقم الهاتف',border:OutlineInputBorder())),
        const SizedBox(height:12),
        TextField(controller:pin,obscureText:true,decoration:const InputDecoration(labelText:'الرقم السري',border:OutlineInputBorder())),
        const SizedBox(height:20),
        SizedBox(width:double.infinity,height:52,child:FilledButton(
          onPressed:loading?null:login,child:Text(loading?'جارٍ الدخول...':'دخول')))
      ]))));
}

class HomePage extends StatefulWidget{
  final Map data; const HomePage({super.key,required this.data});
  @override State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage>{
  late Map data;
  _HomePageState();
  @override void initState(){super.initState();data=Map.from(widget.data);}
  Future<void> transfer() async{
    final to=TextEditingController();
    final amount=TextEditingController();
    final pin=TextEditingController();
    await showDialog(context:context,builder:(_)=>Directionality(
      textDirection:TextDirection.rtl,child:AlertDialog(
      title:const Text('تحويل أموال'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:to,decoration:const InputDecoration(labelText:'حساب المستلم')),
        TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'المبلغ')),
        TextField(controller:pin,obscureText:true,decoration:const InputDecoration(labelText:'الرقم السري')),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إلغاء')),
      FilledButton(onPressed:() async{
        try{
          final r=await http.post(Uri.parse('$api/transfer'),
            headers:{'Content-Type':'application/json'},
            body:jsonEncode({'phone':data['phone'],'pin':pin.text,
              'to_account':to.text,'amount':amount.text,'purpose':'تحويل من التطبيق'}));
          final d=jsonDecode(r.body);
          if(r.statusCode!=200)throw Exception(d['detail']??'فشل التحويل');
          if(context.mounted)Navigator.pop(context);
          if(mounted)ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content:Text('تم التحويل. رقم العملية: ${d['tx_id']}')));
        }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text(e.toString())));}
      },child:const Text('تحويل'))]
    )));
  }
  @override Widget build(BuildContext c)=>Directionality(textDirection:TextDirection.rtl,
    child:Scaffold(
      appBar:AppBar(title:const Text('الحساب المصرفي')),
      body:Padding(padding:const EdgeInsets.all(20),child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(data['name'],style:const TextStyle(fontSize:20)),
              const SizedBox(height:12),
              const Text('الرصيد الحالي'),
              Text('${data['balance']} SDG',style:const TextStyle(fontSize:34,fontWeight:FontWeight.bold)),
              Text('رقم الحساب: ${data['account_no']}'),
            ]))),
          const SizedBox(height:18),
          FilledButton.icon(onPressed:transfer,icon:const Icon(Icons.send),label:const Text('تحويل أموال')),
          const SizedBox(height:10),
          OutlinedButton.icon(onPressed:()=>showDialog(context:c,builder:(_)=>const AlertDialog(
            title:Text('النموذج التجريبي'),
            content:Text('هذا التطبيق Prototype تعليمي. لا يستخدم أموالًا حقيقية ولا يمثل نظامًا مصرفيًا مرخصًا.'),
          )),icon:const Icon(Icons.security),label:const Text('الأمان والضوابط')),
        ])));
}
