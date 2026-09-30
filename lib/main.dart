import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const App());

class Geet {
  String title, lyrics, category, videoUrl;
  bool favorite;
  Geet({required this.title, required this.lyrics, required this.category, required this.videoUrl, this.favorite=false});
  Map<String,dynamic> toJson()=>{'title':title,'lyrics':lyrics,'category':category,'videoUrl':videoUrl,'favorite':favorite};
  factory Geet.fromJson(Map<String,dynamic> j)=>Geet(title:j['title']??'',lyrics:j['lyrics']??'',category:j['category']??'Christian Geet',videoUrl:j['videoUrl']??'',favorite:j['favorite']??false);
}

class Store {
  static const key='geets';
  static Future<List<Geet>> load() async {
    final p=await SharedPreferences.getInstance(), raw=p.getString(key);
    if(raw==null)return [];
    return (jsonDecode(raw) as List).map((e)=>Geet.fromJson(e)).toList();
  }
  static Future<void> save(List<Geet> x) async {
    final p=await SharedPreferences.getInstance();
    await p.setString(key,jsonEncode(x.map((e)=>e.toJson()).toList()));
  }
}

class App extends StatelessWidget {
  const App({super.key});
  Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'Christian Geet & Zaboor',theme:ThemeData(useMaterial3:true,colorSchemeSeed:Colors.indigo),home:const Home());
}

class Home extends StatefulWidget { const Home({super.key}); State<Home> createState()=>_Home(); }
class _Home extends State<Home> {
  List<Geet> items=[]; String q=''; bool fav=false;
  void initState(){super.initState();load();}
  Future<void> load() async {items=await Store.load();setState((){});}
  Future<void> edit([Geet? old]) async {
    final g=await Navigator.push<Geet>(context,MaterialPageRoute(builder:(_)=>EditPage(old:old)));
    if(g==null)return;
    setState(()=>old==null?items.add(g):items[items.indexOf(old)]=g); await Store.save(items);
  }
  Future<void> del(Geet g) async {
    final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('Delete / حذف'),content:Text(g.title),actions:[
      TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),
      FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Delete'))]))??false;
    if(ok){setState(()=>items.remove(g));await Store.save(items);}
  }
  Widget build(BuildContext c){
    final list=items.where((g)=>(!fav||g.favorite)&&('${g.title} ${g.category}').toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      appBar:AppBar(title:const Text('✝️ Christian Geet & Zaboor'),actions:[
        IconButton(icon:const Icon(Icons.search),onPressed:() async {final x=await showDialog<String>(context:context,builder:(_){final t=TextEditingController(text:q);return AlertDialog(title:const Text('Search / تلاش'),content:TextField(controller:t,autofocus:true),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,t.text),child:const Text('Search'))];});});if(x!=null)setState(()=>q=x);})
      ]),
      body:list.isEmpty?const Center(child:Text('ابھی کوئی Geet نہیں ہے\n+ دباکر نیا Geet شامل کریں',textAlign:TextAlign.center)):ListView.builder(itemCount:list.length,itemBuilder:(_,i){final g=list[i];return Card(child:ListTile(leading:CircleAvatar(child:Icon(g.category=='Zaboor'?Icons.menu_book:Icons.music_note)),title:Text(g.title),subtitle:Text(g.category),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>GeetPage(g,onChanged:(){setState((){});Store.save(items);}))),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')edit(g);if(v=='delete')del(g);if(v=='fav'){setState(()=>g.favorite=!g.favorite);Store.save(items);}},itemBuilder:(_)=>[PopupMenuItem(value:'fav',child:Text(g.favorite?'Remove Favorite':'Favorite / پسندیدہ')),const PopupMenuItem(value:'edit',child:Text('Edit / ترمیم')),const PopupMenuItem(value:'delete',child:Text('Delete / حذف'))])));}),
      floatingActionButton:FloatingActionButton.extended(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('Naya Geet')),
      bottomNavigationBar:NavigationBar(selectedIndex:fav?1:0,onDestinationSelected:(i)=>setState(()=>fav=i==1),destinations:const[NavigationDestination(icon:Icon(Icons.music_note),label:'Christian Geet'),NavigationDestination(icon:Icon(Icons.favorite),label:'Favorites')])
    );
  }
}

class EditPage extends StatefulWidget { final Geet? old; const EditPage({super.key,this.old}); State<EditPage> createState()=>_Edit(); }
class _Edit extends State<EditPage>{
  late TextEditingController t,l,v; String cat='Christian Geet';
  void initState(){super.initState();final g=widget.old;t=TextEditingController(text:g?.title??'');l=TextEditingController(text:g?.lyrics??'');v=TextEditingController(text:g?.videoUrl??'');cat=g?.category??'Christian Geet';}
  void dispose(){t.dispose();l.dispose();v.dispose();super.dispose();}
  Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(widget.old==null?'Naya Geet / نیا Geet':'Edit / ترمیم')),body:ListView(padding:const EdgeInsets.all(16),children:[
    TextField(controller:t,decoration:const InputDecoration(labelText:'Geet ka Naam / گیت کا نام',border:OutlineInputBorder())),
    const SizedBox(height:12),DropdownButtonFormField<String>(value:cat,decoration:const InputDecoration(labelText:'Category / قسم',border:OutlineInputBorder()),items:const['Christian Geet','Zaboor','Worship','Christmas','Easter','Sunday School'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>cat=x!)),
    const SizedBox(height:12),TextField(controller:l,minLines:10,maxLines:20,decoration:const InputDecoration(labelText:'Geet ke Bol / گیت کے بول',alignLabelWithHint:true,border:OutlineInputBorder())),
    const SizedBox(height:12),TextField(controller:v,keyboardType:TextInputType.url,decoration:const InputDecoration(labelText:'YouTube / Video Link',border:OutlineInputBorder())),
    const SizedBox(height:20),FilledButton.icon(onPressed:(){if(t.text.trim().isEmpty)return;Navigator.pop(c,Geet(title:t.text.trim(),lyrics:l.text,category:cat,videoUrl:v.text.trim(),favorite:widget.old?.favorite??false));},icon:const Icon(Icons.save),label:const Text('Save / محفوظ کریں'))
  ]));
}

class GeetPage extends StatelessWidget {
  final Geet g; final VoidCallback onChanged;
  const GeetPage(this.g,{super.key,required this.onChanged});
  Future<void> video(BuildContext c) async {
    if(g.videoUrl.isEmpty){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Video link محفوظ نہیں ہے')));return;}
    final u=Uri.tryParse(g.videoUrl); if(u!=null&&await canLaunchUrl(u)){await launchUrl(u,mode:LaunchMode.externalApplication);} else if(c.mounted){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Video link درست نہیں ہے')));}
  }
  Widget build(BuildContext c)=>Scaffold(appBar:AppBar(leading:IconButton(icon:const Icon(Icons.play_circle_fill),onPressed:()=>video(c)),title:Text(g.title),actions:[IconButton(icon:Icon(g.favorite?Icons.favorite:Icons.favorite_border),onPressed:(){g.favorite=!g.favorite;onChanged();})]),body:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Chip(label:Text(g.category)),const SizedBox(height:18),Text(g.lyrics,style:const TextStyle(fontSize:20,height:1.7)),const SizedBox(height:25),if(g.videoUrl.isNotEmpty)FilledButton.icon(onPressed:()=>video(c),icon:const Icon(Icons.play_arrow),label:const Text('Geet ki Video چلائیں'))])));
}
