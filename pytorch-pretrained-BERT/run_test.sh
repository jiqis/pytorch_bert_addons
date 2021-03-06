#!jar xvf repo.zip
# sudo yum update
# source activate pytorch_p36
# pip install virtualenv
# virtualenv venv
# source venv/bin/activate

# sudo yum install -y gcc kernel-devel-$(uname -r)
# sudo yum update -y
rank=0
world_size=2
local_rank=-1
dist_url="tcp://172.31.40.232:23456"
annotated_text="annotated_stuff.txt"
text_file="transcripts_presentation.txt"
vocab_file="./bert-base-uncased-vocab.txt"
word_file="allwords.txt"
threshold="5"
train_batch_size=4
output_file="./vocab.txt"
epoch=1
gpus=1
learning_rate="3e-5"
address="pytorch_pretrained_bert"
data="data"
echo "$output_file"

if ! options=$(getopt -o ab:e: -l all,annotated_text:,text_file:,vocab_file:,word_file:,output_file,threshold:,batch_size:,epoch: -- "$@")
then
    # something went wrong, getopt will put out an error message for us
    exit 1
fi
set -- $options
#
# while getopts "a" option
# do
# case $option
# in
while [ $# -gt 0 ]
do
case $1 in
  --annotated_text)annotated_text="$2" ; shift;;
  --text_file)text_file="$2" ; shift;;
  --vocab_file)vocab_file="$2" ; shift;;
  --word_file)word_file="$2" ; shift;;
  --output_file)output_file="$2" ; shift;;
  --threshold)threshold=$2 ; shift;;
  -b| --batch_size)train_batch_size=$2 ; shift;;
  -e| --epoch)epoch=$2 ; shift;;
  -l| --learning_rate)learning_rate=$2 ; shift;;
  -a| --all) pip install -r requirements.txt

python -m spacy download en_core_web_lg
mkdir data
mkdir test
wget https://s3.amazonaws.com/models.huggingface.co/bert/bert-base-uncased-vocab.txt


cp bert-base-uncased-vocab.txt $data/
chmod +x "$address/1_extract_vocab.sh"

echo "Vocabulary issues"
bash $address/1_extract_vocab.sh -i $data/$annotated_text -o $data/$word_file
python setup.py install
# python 2_find_missing_tokens.py --vocab_file bert-base-uncased-vocab.txt > new_vocab.txt
# python python1_data.py
# python 3_add_missing_tokens_to_vocab.py --vocab_file bert-base-uncased-vocab.txt --ouput_file full_vocab.txt --missing_tokens_file new_vocab.txt
# mv full_vocab.txt vocab.txt
# python python2_data.py
mkdir -p training
mkdir -p test
python $address/vocab_treatment.py --vocab_file $data/$vocab_file --word_file $data/$word_file --threshold $threshold --output_file $output_file --annotated_text_file $data/$annotated_text --text_file $data/$text_file
echo "Prepare text data"
#python $address/prepare_all_texts_for_bert.py --input_folder training/ --ouput_file training_text.txt
python $address/prepare_all_texts_for_bert.py --input_folder test/ --ouput_file test_text.txt
rm -r training/
rm -r test/
echo 'generating data for train'
#python $address/pregenerate_training_data.py --train_corpus "training_text.txt" --bert_model vocab.txt --do_lower_case --output_dir training/ --epochs_to_generate 2 --max_seq_len 512
python $address/pregenerate_training_data.py --train_corpus "test_text.txt" --bert_model vocab.txt --do_lower_case --output_dir test/ --epochs_to_generate $epoch --max_seq_len 512 ;;
(--) shift; break;;
(-*) echo "$0: error - unrecognized option $1" 1>&2 exit1;;
(*) break ;;

esac
shift
done


rm -r log
mkdir log
echo 'tensorboard setup'
# tensorboard --logdir=/log --host 0.0.0.0 --port 6006 &
echo 'finetuning starting'
export CUDA_VISIBLE_DEVICES="0,1,2,3,4,5,6,7,8"
python $address/finetune_on_pregenerated.py --use_all_gpus --world_size $world_size --local_rank $local_rank --rank $rank --dist_url $dist_url --pregenerated_data test/ --bert_model bert-base-uncased --do_lower_case --output_dir finetuned_lm/ --epochs $epoch --train_batch_size $train_batch_size --learning_rate $learning_rate --tensorboard
